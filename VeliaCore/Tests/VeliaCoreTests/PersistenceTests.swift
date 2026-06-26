import XCTest
@testable import VeliaCore

final class PersistenceTests: XCTestCase {
    private let device = UUID()
    private func meta(updated: Date) -> SyncMetadata {
        SyncMetadata(createdAt: Date(timeIntervalSince1970: 0), updatedAt: updated, deviceID: device)
    }

    private func period(_ updated: Date, start: Date = Date(timeIntervalSince1970: 1000)) -> PeriodRecord {
        PeriodRecord(sync: meta(updated: updated), startDate: start)
    }

    func testSyncMetadataDefaults() {
        let m = SyncMetadata(deviceID: device)
        XCTAssertFalse(m.isDeleted)
        XCTAssertNotEqual(m.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    func testUpsertAndFetch() async throws {
        let repo = InMemoryRepository<PeriodRecord>()
        let p = period(Date(timeIntervalSince1970: 10))
        try await repo.upsert(p)
        let fetched = try await repo.fetch(id: p.id)
        XCTAssertEqual(fetched, p)
        let all = try await repo.all()
        XCTAssertEqual(all.count, 1)
    }

    func testSoftDeleteExcludesFromLiveButRetains() async throws {
        let repo = InMemoryRepository<PeriodRecord>()
        let p = period(Date(timeIntervalSince1970: 10))
        try await repo.upsert(p)
        try await repo.softDelete(id: p.id, at: Date(timeIntervalSince1970: 20), deviceID: device)

        let live = try await repo.all()
        XCTAssertTrue(live.isEmpty, "soft-deleted record must not appear in live results")
        let gone = await repo.fetch(id: p.id)
        XCTAssertNil(gone)

        let withDeleted = try await repo.all(includingDeleted: true)
        XCTAssertEqual(withDeleted.count, 1, "tombstone must be retained for sync")
        XCTAssertTrue(withDeleted[0].sync.isDeleted)
    }

    func testLWWPicksNewerUpdate() {
        let older = period(Date(timeIntervalSince1970: 100))
        var newer = older
        newer.sync.updatedAt = Date(timeIntervalSince1970: 200)
        newer.flow = .heavy
        XCTAssertEqual(LWW.resolve(older, newer), newer)
        XCTAssertEqual(LWW.resolve(newer, older), newer)
    }

    func testMergeAppliesLWW() async throws {
        let base = period(Date(timeIntervalSince1970: 100))
        let repo = InMemoryRepository<PeriodRecord>([base])

        // Incoming newer edit for same id wins.
        var incoming = base
        incoming.sync.updatedAt = Date(timeIntervalSince1970: 300)
        incoming.flow = .light
        try await repo.merge([incoming])
        let afterNewer = await repo.fetch(id: base.id)
        XCTAssertEqual(afterNewer?.flow, .light)

        // Incoming older edit loses.
        var stale = base
        stale.sync.updatedAt = Date(timeIntervalSince1970: 50)
        stale.flow = .heavy
        try await repo.merge([stale])
        let afterStale = await repo.fetch(id: base.id)
        XCTAssertEqual(afterStale?.flow, .light, "older incoming must not override newer")
    }

    func testMergeDoesNotResurrectDeleted() async throws {
        let base = period(Date(timeIntervalSince1970: 100))
        let repo = InMemoryRepository<PeriodRecord>([base])
        try await repo.softDelete(id: base.id, at: Date(timeIntervalSince1970: 400), deviceID: device)

        // A stale (pre-deletion) incoming edit must not bring the record back.
        var stale = base
        stale.sync.updatedAt = Date(timeIntervalSince1970: 200)
        try await repo.merge([stale])
        let resurrected = await repo.fetch(id: base.id)
        XCTAssertNil(resurrected, "LWW: deletion (newer) must win over stale edit")
    }

    func testRecordsAreCodableRoundTrip() throws {
        let p = period(Date(timeIntervalSince1970: 10))
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(PeriodRecord.self, from: data)
        XCTAssertEqual(decoded, p)
    }
}
