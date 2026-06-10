import Foundation
import GRDB

// ⚠️ Phase 1 implementation target (requires iOS app build with GRDB/SQLCipher; not compiled by the
// VeliaCore SwiftPM package). Architecture: docs/architecture.md §3 (schema), §4 (encryption).
// Invariant #3: PHI encrypted at rest via SQLCipher; #5: every table carries sync columns.

public struct AppDatabase {
    public let pool: DatabasePool

    /// Opens the encrypted database at `url` using the raw 32-byte key from `DatabaseKeyProvider`.
    public init(url: URL, key: Data) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.usePassphrase(key)          // SQLCipher: PRAGMA key
        }
        pool = try DatabasePool(path: url.path, configuration: config)
        try Self.migrator.migrate(pool)
    }

    /// Append-only migrations. NEVER edit a shipped migration (engineering-practices.md §3.2).
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            func syncColumns(_ t: TableDefinition) {
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deviceID", .text).notNull()
                t.column("deletedAt", .datetime)        // tombstone — soft delete only
            }

            try db.create(table: "period_events") { t in
                syncColumns(t)
                t.column("startDate", .datetime).notNull()
                t.column("endDate", .datetime)
                t.column("flow", .text)
                t.column("isSpotting", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "symptom_entries") { t in
                syncColumns(t)
                t.column("date", .datetime).notNull()
                t.column("type", .text).notNull()
                t.column("value", .double).notNull()
                t.column("note", .text)
            }
            try db.create(table: "fertility_entries") { t in
                syncColumns(t)
                t.column("date", .datetime).notNull()
                t.column("bbtCelsius", .double)
                t.column("cervicalMucus", .text)
                t.column("lhTest", .text)
                t.column("source", .text).notNull().defaults(to: "manual")
            }
            // Remaining tables (notes, tags, tag_values, sex_entries, user_profile, reminders,
            // prediction_cache) follow the same syncColumns(...) pattern — see architecture.md §3.2.
        }

        return migrator
    }
}
