import Foundation

// MARK: - Sync-ready persistence model (pure Swift, no GRDB)

//
// Architecture invariant #5: every persisted row is sync-ready (UUID id, updated_at, device_id,
// deleted_at) even though no sync code ships at MVP. This file defines the storage contracts, the
// soft-delete semantics, and the last-write-wins merge — all testable without a database or iOS.
// The GRDB/SQLCipher implementation in `VeliaData` conforms to these same protocols.

/// Metadata carried by every persisted record. See architecture.md §3.1.
public struct SyncMetadata: Sendable, Equatable, Codable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deviceID: UUID
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deviceID: UUID,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool {
        deletedAt != nil
    }

    /// Stamp an edit: bump `updatedAt` and record which device made it.
    public mutating func touch(at date: Date = Date(), deviceID: UUID) {
        updatedAt = date
        self.deviceID = deviceID
    }
}

/// Anything persisted by Velia. `id` is derived from the sync metadata.
public protocol SyncRecord: Sendable, Identifiable, Equatable, Codable {
    var sync: SyncMetadata { get set }
}

public extension SyncRecord {
    var id: UUID {
        sync.id
    }

    var isDeleted: Bool {
        sync.isDeleted
    }
}

// MARK: - Last-write-wins conflict resolution

public enum LWW {
    /// Pick the record with the newer `updatedAt`; ties resolve to `a` (the local copy by convention).
    public static func resolve<T: SyncRecord>(_ a: T, _ b: T) -> T {
        a.sync.updatedAt >= b.sync.updatedAt ? a : b
    }
}

// MARK: - Repository contract

public protocol Repository<Element>: Sendable {
    associatedtype Element: SyncRecord

    /// Live records (deleted excluded) unless `includingDeleted` is true.
    func all(includingDeleted: Bool) async throws -> [Element]
    func fetch(id: UUID) async throws -> Element?
    /// Insert or replace (local authoritative write; caller is responsible for bumping `updatedAt`).
    func upsert(_ element: Element) async throws
    /// Tombstone a record (soft delete) — never a hard delete.
    func softDelete(id: UUID, at date: Date, deviceID: UUID) async throws
    /// Merge incoming records using LWW (the future sync entry point).
    func merge(_ incoming: [Element]) async throws
}

public extension Repository {
    func all() async throws -> [Element] {
        try await all(includingDeleted: false)
    }
}

// MARK: - In-memory reference implementation (used by tests, previews, and as the GRDB spec)

public actor InMemoryRepository<Element: SyncRecord>: Repository {
    private var storage: [UUID: Element] = [:]

    public init(_ seed: [Element] = []) {
        for element in seed {
            storage[element.id] = element
        }
    }

    public func all(includingDeleted: Bool) -> [Element] {
        storage.values
            .filter { includingDeleted || !$0.sync.isDeleted }
            .sorted { $0.sync.createdAt < $1.sync.createdAt }
    }

    public func fetch(id: UUID) -> Element? {
        guard let element = storage[id], !element.sync.isDeleted else { return nil }
        return element
    }

    public func upsert(_ element: Element) {
        storage[element.id] = element
    }

    public func softDelete(id: UUID, at date: Date, deviceID: UUID) {
        guard var element = storage[id] else { return }
        element.sync.deletedAt = date
        element.sync.touch(at: date, deviceID: deviceID)
        storage[id] = element
    }

    public func merge(_ incoming: [Element]) {
        for record in incoming {
            if let current = storage[record.id] {
                storage[record.id] = LWW.resolve(current, record)
            } else {
                storage[record.id] = record
            }
        }
    }
}

// MARK: - Concrete records (the MVP schema as value types)

public enum FlowIntensity: String, Sendable, Codable, CaseIterable {
    case spotting, light, medium, heavy
}

public struct PeriodRecord: SyncRecord {
    public var sync: SyncMetadata
    public var startDate: Date
    public var endDate: Date?
    public var flow: FlowIntensity?
    public var isSpotting: Bool

    public init(
        sync: SyncMetadata,
        startDate: Date,
        endDate: Date? = nil,
        flow: FlowIntensity? = nil,
        isSpotting: Bool = false
    ) {
        self.sync = sync
        self.startDate = startDate
        self.endDate = endDate
        self.flow = flow
        self.isSpotting = isSpotting
    }
}

public struct SymptomRecord: SyncRecord {
    public var sync: SyncMetadata
    public var date: Date
    public var type: String // e.g. "mood", "energy", "sleep", "pain"
    public var value: Double
    public var note: String?

    public init(sync: SyncMetadata, date: Date, type: String, value: Double, note: String? = nil) {
        self.sync = sync
        self.date = date
        self.type = type
        self.value = value
        self.note = note
    }
}

public struct FertilityRecord: SyncRecord {
    public var sync: SyncMetadata
    public var date: Date
    public var bbtCelsius: Double?
    public var cervicalMucus: String?
    public var lhTest: String? // "negative" / "peak"
    public var source: String // "manual" / "healthkit"

    public init(
        sync: SyncMetadata,
        date: Date,
        bbtCelsius: Double? = nil,
        cervicalMucus: String? = nil,
        lhTest: String? = nil,
        source: String = "manual"
    ) {
        self.sync = sync
        self.date = date
        self.bbtCelsius = bbtCelsius
        self.cervicalMucus = cervicalMucus
        self.lhTest = lhTest
        self.source = source
    }
}
