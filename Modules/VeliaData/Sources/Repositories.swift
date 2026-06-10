import Foundation
import GRDB
import VeliaCore

// ⚠️ Phase 1 implementation target (requires GRDB; not compiled by VeliaCore SwiftPM).
// GRDB-backed implementation of VeliaCore.Repository. The domain record (PeriodRecord) stays pure in
// VeliaCore; this layer maps it to/from a GRDB row so the core never imports GRDB (architecture §2).

/// GRDB persistence row for PeriodRecord (flat columns matching the v1 schema).
struct PeriodRow: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "period_events"
    var id: String
    var createdAt: Date
    var updatedAt: Date
    var deviceID: String
    var deletedAt: Date?
    var startDate: Date
    var endDate: Date?
    var flow: String?
    var isSpotting: Bool

    init(_ r: PeriodRecord) {
        id = r.sync.id.uuidString
        createdAt = r.sync.createdAt
        updatedAt = r.sync.updatedAt
        deviceID = r.sync.deviceID.uuidString
        deletedAt = r.sync.deletedAt
        startDate = r.startDate
        endDate = r.endDate
        flow = r.flow?.rawValue
        isSpotting = r.isSpotting
    }

    var record: PeriodRecord {
        PeriodRecord(
            sync: SyncMetadata(
                id: UUID(uuidString: id) ?? UUID(),
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceID: UUID(uuidString: deviceID) ?? UUID(),
                deletedAt: deletedAt
            ),
            startDate: startDate,
            endDate: endDate,
            flow: flow.flatMap(FlowIntensity.init(rawValue:)),
            isSpotting: isSpotting
        )
    }
}

public struct GRDBPeriodRepository: Repository {
    public typealias Element = PeriodRecord
    private let pool: DatabasePool

    public init(database: AppDatabase) { pool = database.pool }

    public func all(includingDeleted: Bool) async throws -> [PeriodRecord] {
        try await pool.read { db in
            let rows = includingDeleted
                ? try PeriodRow.order(Column("createdAt")).fetchAll(db)
                : try PeriodRow.filter(Column("deletedAt") == nil).order(Column("createdAt")).fetchAll(db)
            return rows.map(\.record)
        }
    }

    public func fetch(id: UUID) async throws -> PeriodRecord? {
        try await pool.read { db in
            try PeriodRow.filter(Column("id") == id.uuidString && Column("deletedAt") == nil)
                .fetchOne(db)?.record
        }
    }

    public func upsert(_ element: PeriodRecord) async throws {
        try await pool.write { db in try PeriodRow(element).upsert(db) }
    }

    public func softDelete(id: UUID, at date: Date, deviceID: UUID) async throws {
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE period_events SET deletedAt = ?, updatedAt = ?, deviceID = ? WHERE id = ?",
                arguments: [date, date, deviceID.uuidString, id.uuidString]
            )
        }
    }

    public func merge(_ incoming: [PeriodRecord]) async throws {
        try await pool.write { db in
            for record in incoming {
                if let existing = try PeriodRow.filter(Column("id") == record.id.uuidString).fetchOne(db) {
                    let winner = LWW.resolve(existing.record, record)   // last-write-wins
                    try PeriodRow(winner).upsert(db)
                } else {
                    try PeriodRow(record).insert(db)
                }
            }
        }
    }
}
