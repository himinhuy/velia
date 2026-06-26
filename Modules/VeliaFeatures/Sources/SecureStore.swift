import CryptoKit
import Foundation
import Security
import VeliaCore

/// What CycleStore persists. `UserProfile` isn't Codable, so its fields are flattened here.
public struct PersistedState: Codable {
    public var hasOnboarded: Bool
    public var birthYear: Int?
    public var typicalCycleLength: Int?
    public var typicalPeriodLength: Int
    public var segmentRaw: String
    public var periodDays: [PeriodRecord]
    public var symptoms: [SymptomRecord]
    /// Optional for migration: pre-mode states decode to nil → default .period.
    public var modeRaw: String?
    public var fertility: [FertilityRecord]?
}

/// Persistence boundary so tests/previews can run without touching the Keychain or disk.
public protocol CyclePersistence: Sendable {
    func load() -> PersistedState?
    func save(_ state: PersistedState)
}

/// Encrypted-at-rest store: PHI is AES-GCM sealed with a 256-bit key kept in the Keychain
/// (architecture §0 invariant #3 — "encrypted at rest, key in Keychain"). This is the interim
/// ahead of the full SQLCipher/GRDB + Secure-Enclave-gated key in Phase 1; the data layout stays
/// sync-ready so migration is mechanical.
public final class SecureStore: CyclePersistence, @unchecked Sendable {
    /// Legacy single-profile store (the first/default profile inherits this file).
    public static let shared = SecureStore()

    private let keychainAccount = "app.velia.db-key"
    private let fileName: String

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// `fileName` scopes the encrypted file — one per profile. All files share the device key.
    public init(fileName: String = "velia-state.enc") {
        self.fileName = fileName
    }

    /// Delete this profile's encrypted file (when a profile is removed).
    public func deleteFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: CyclePersistence

    public func load() -> PersistedState? {
        loadCodable(PersistedState.self)
    }

    public func save(_ state: PersistedState) {
        saveCodable(state)
    }

    // MARK: Generic encrypted Codable (also used for the profile registry)

    public func loadCodable<T: Decodable>(_: T.Type) -> T? {
        guard let blob = try? Data(contentsOf: fileURL) else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: blob)
            let clear = try AES.GCM.open(box, using: key())
            return try JSONDecoder().decode(T.self, from: clear)
        } catch {
            return nil // corrupt or key rotated — start fresh rather than crash
        }
    }

    public func saveCodable(_ value: some Encodable) {
        do {
            let clear = try JSONEncoder().encode(value)
            let sealed = try AES.GCM.seal(clear, using: key())
            guard let combined = sealed.combined else { return }
            try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Best-effort; a failed write must never crash the app.
        }
    }

    // MARK: Keychain-held symmetric key

    private func key() throws -> SymmetricKey {
        if let existing = readKey() { return existing }
        let new = SymmetricKey(size: .bits256)
        storeKey(new)
        return new
    }

    private func readKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func storeKey(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            // Available after first unlock, never leaves this device, not in backups.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(attrs as CFDictionary)
        SecItemAdd(attrs as CFDictionary, nil)
    }
}
