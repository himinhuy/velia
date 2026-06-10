import Foundation
import CryptoKit

// MARK: - Encrypted export / import codec (pure, testable)
//
// Implements the MVP "one-tap encrypted export" + import (prd.md §5.1, architecture.md §4).
// The codec seals a serialized payload with AES-GCM. It is intentionally KDF-agnostic: callers pass
// the SymmetricKey. Production passphrase→key derivation MUST use a slow KDF (PBKDF2/Argon2id) in the
// security layer — NOT a fast hash — because backups travel off-device. The `salt` is carried in the
// envelope so import can re-derive the key from the user's passphrase.

public struct EncryptedBackup: Codable, Sendable, Equatable {
    public let version: Int
    public let createdAt: Date
    public let salt: Data    // for the caller's passphrase KDF
    public let sealed: Data  // AES.GCM combined box: nonce ‖ ciphertext ‖ tag
}

public enum BackupError: Error, Equatable {
    case sealFailed
    case unsupportedVersion(Int)
}

public enum BackupCodec {
    public static let currentVersion = 1

    /// Encrypt + serialize a Codable payload into a portable backup blob.
    public static func export<T: Encodable>(_ value: T,
                                            key: SymmetricKey,
                                            salt: Data = randomBytes(16),
                                            now: Date = Date()) throws -> Data {
        let plaintext = try JSONEncoder().encode(value)
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw BackupError.sealFailed }
        let envelope = EncryptedBackup(version: currentVersion, createdAt: now, salt: salt, sealed: combined)
        return try JSONEncoder().encode(envelope)
    }

    /// Decrypt + decode a backup blob. Throws on wrong key or tampering (AES-GCM auth failure).
    public static func importBackup<T: Decodable>(_ data: Data, key: SymmetricKey, as type: T.Type) throws -> T {
        let envelope = try JSONDecoder().decode(EncryptedBackup.self, from: data)
        guard envelope.version <= currentVersion else {
            throw BackupError.unsupportedVersion(envelope.version)
        }
        let box = try AES.GCM.SealedBox(combined: envelope.sealed)
        let plaintext = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(T.self, from: plaintext)
    }

    /// Read the unencrypted envelope header (version/date/salt) without the key — e.g. to derive the
    /// key from the user's passphrase before decrypting.
    public static func header(_ data: Data) throws -> EncryptedBackup {
        try JSONDecoder().decode(EncryptedBackup.self, from: data)
    }

    public static func randomBytes(_ count: Int) -> Data {
        Data(SymmetricKey(size: .init(bitCount: count * 8)).withUnsafeBytes(Array.init))
    }
}
