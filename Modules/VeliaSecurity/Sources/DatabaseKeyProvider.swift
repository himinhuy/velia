import Foundation
import Security
import LocalAuthentication

// ⚠️ Phase 1 implementation target. Requires the iOS app build (Tuist/Xcode) — references the
// Security & LocalAuthentication frameworks and is NOT compiled by the VeliaCore SwiftPM package.
// Architecture: docs/architecture.md §4 (encryption). Invariant #3: the DB key never exists in
// plaintext outside this Secure-Enclave-gated path.

public enum DatabaseKeyError: Error {
    case enclaveUnavailable
    case keyGenerationFailed(String)
    case wrapFailed(String)
    case unwrapFailed(String)
    case keychainFailed(OSStatus)
}

/// Produces the 256-bit SQLCipher database key, wrapped by a Secure-Enclave key and stored in the
/// Keychain. On first launch it generates the key; thereafter it unwraps it behind biometric/passcode.
public struct DatabaseKeyProvider {
    private let keychainAccount = "app.velia.db.wrappedKey"
    private let enclaveTag = "app.velia.enclave.kek".data(using: .utf8)!

    public init() {}

    /// Returns the raw 32-byte DB key, creating + persisting it on first run.
    /// `context` carries an already-evaluated biometric/passcode authentication.
    public func loadOrCreateKey(context: LAContext) throws -> Data {
        if let wrapped = try readWrappedKey() {
            return try unwrap(wrapped, context: context)
        }
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { throw DatabaseKeyError.keyGenerationFailed("SecRandom \(status)") }
        let wrapped = try wrap(bytes, context: context)
        try storeWrappedKey(wrapped)
        return bytes
    }

    /// Cryptographically erase the key (full-delete). After this the DB file is unrecoverable.
    public func destroyKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DatabaseKeyError.keychainFailed(status)
        }
    }

    // MARK: Secure Enclave wrap/unwrap (ECIES)

    private func enclaveKey(context: LAContext) throws -> SecKey {
        // Reuse an existing enclave key if present, else create one gated by biometry/passcode.
        if let existing = try? loadEnclaveKey() { return existing }

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .userPresence],
            &error
        ) else { throw DatabaseKeyError.wrapFailed("access control: \(String(describing: error))") }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: enclaveTag,
                kSecAttrAccessControl as String: access,
                kSecUseAuthenticationContext as String: context,
            ],
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw DatabaseKeyError.enclaveUnavailable
        }
        return key
    }

    private func loadEnclaveKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: enclaveTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else { throw DatabaseKeyError.keychainFailed(status) }
        return item as! SecKey
    }

    private func wrap(_ plaintext: Data, context: LAContext) throws -> Data {
        let priv = try enclaveKey(context: context)
        guard let pub = SecKeyCopyPublicKey(priv) else { throw DatabaseKeyError.wrapFailed("no public key") }
        var error: Unmanaged<CFError>?
        guard let cipher = SecKeyCreateEncryptedData(
            pub, .eciesEncryptionCofactorVariableIVX963SHA256AESGCM, plaintext as CFData, &error
        ) else { throw DatabaseKeyError.wrapFailed(String(describing: error)) }
        return cipher as Data
    }

    private func unwrap(_ ciphertext: Data, context: LAContext) throws -> Data {
        let priv = try enclaveKey(context: context)
        var error: Unmanaged<CFError>?
        guard let plain = SecKeyCreateDecryptedData(
            priv, .eciesEncryptionCofactorVariableIVX963SHA256AESGCM, ciphertext as CFData, &error
        ) else { throw DatabaseKeyError.unwrapFailed(String(describing: error)) }
        return plain as Data
    }

    // MARK: Keychain storage of the wrapped blob

    private func storeWrappedKey(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw DatabaseKeyError.keychainFailed(status) }
    }

    private func readWrappedKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw DatabaseKeyError.keychainFailed(status)
        }
        return data
    }
}
