import CryptoKit
import XCTest
@testable import VeliaCore

final class BackupCodecTests: XCTestCase {
    private func samplePeriods() -> [PeriodRecord] {
        let device = UUID()
        return (0 ..< 3).map { i in
            PeriodRecord(
                sync: SyncMetadata(updatedAt: Date(timeIntervalSince1970: Double(i)), deviceID: device),
                startDate: Date(timeIntervalSince1970: Double(i) * 1000),
                flow: .medium
            )
        }
    }

    func testRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let periods = samplePeriods()
        let blob = try BackupCodec.export(periods, key: key)
        let restored = try BackupCodec.importBackup(blob, key: key, as: [PeriodRecord].self)
        XCTAssertEqual(restored, periods)
    }

    func testWrongKeyFails() throws {
        let blob = try BackupCodec.export(samplePeriods(), key: SymmetricKey(size: .bits256))
        let wrongKey = SymmetricKey(size: .bits256)
        XCTAssertThrowsError(try BackupCodec.importBackup(blob, key: wrongKey, as: [PeriodRecord].self))
    }

    func testTamperedCiphertextFails() throws {
        let key = SymmetricKey(size: .bits256)
        var blob = try BackupCodec.export(samplePeriods(), key: key)
        // Flip a byte well inside the JSON (the base64 sealed payload).
        let idx = blob.count - 10
        blob[idx] = blob[idx] ^ 0xFF
        XCTAssertThrowsError(try BackupCodec.importBackup(blob, key: key, as: [PeriodRecord].self))
    }

    func testHeaderReadableWithoutKey() throws {
        let key = SymmetricKey(size: .bits256)
        let salt = BackupCodec.randomBytes(16)
        let blob = try BackupCodec.export(samplePeriods(), key: key, salt: salt)
        let header = try BackupCodec.header(blob)
        XCTAssertEqual(header.version, BackupCodec.currentVersion)
        XCTAssertEqual(header.salt, salt) // salt recoverable for passphrase KDF
    }

    func testRandomBytesLengthAndEntropy() {
        let a = BackupCodec.randomBytes(16)
        let b = BackupCodec.randomBytes(16)
        XCTAssertEqual(a.count, 16)
        XCTAssertNotEqual(a, b)
    }
}
