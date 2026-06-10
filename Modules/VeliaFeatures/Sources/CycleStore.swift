import Foundation
import Observation
import VeliaCore

/// App-wide observable state + the bridge to the on-device prediction engine.
///
/// **In-memory only by design.** Logged cycle data is PHI; architecture §0 invariant #3 requires it
/// encrypted at rest (SQLCipher), which lands when VeliaData is wired (Phase 1 finish). Until then we
/// keep everything in RAM rather than writing plaintext PHI to disk. Data therefore resets on cold
/// launch — acceptable for this UI phase, and it keeps the privacy invariant unbroken.
@MainActor
@Observable
public final class CycleStore {
    public private(set) var profile: UserProfile
    public private(set) var periods: [PeriodRecord]
    public var hasOnboarded: Bool

    private let predictor = BayesianCyclePredictor()
    private let deviceID = UUID()

    public init(profile: UserProfile = UserProfile(),
                periods: [PeriodRecord] = [],
                hasOnboarded: Bool = false) {
        self.profile = profile
        self.periods = periods
        self.hasOnboarded = hasOnboarded
    }

    // MARK: - Derived data

    /// Period starts sorted oldest → newest.
    public var sortedStarts: [Date] {
        periods.map(\.startDate).sorted()
    }

    public var lastPeriodStart: Date? { sortedStarts.last }

    /// History as engine events.
    private var history: [PeriodEvent] {
        periods.map { PeriodEvent(id: $0.id, startDate: $0.startDate, endDate: $0.endDate) }
    }

    /// The calibrated on-device prediction (nil until at least one period is known).
    public var prediction: Prediction? {
        guard !history.isEmpty else { return nil }
        let asOf = lastPeriodStart ?? Date()
        return predictor.predict(history: history, profile: profile, asOf: asOf)
    }

    /// 1-based day of the current cycle (days since last start + 1), or nil.
    public func cycleDay(asOf now: Date = Date()) -> Int? {
        guard let last = lastPeriodStart else { return nil }
        let days = Int(DayMath.daysBetween(last, now).rounded(.down))
        return max(days + 1, 1)
    }

    /// Coarse display phase for the Today header, derived from cycle day + predicted length.
    /// (The engine owns the *predictive* outputs; this is just a friendly current-state label.)
    public func displayPhase(asOf now: Date = Date()) -> CyclePhase {
        guard let day = cycleDay(asOf: now) else { return .unknown }
        let cycleLen = Double(profile.typicalCycleLength ?? 28)
        let ovulationDay = Int((cycleLen - 14).rounded())
        switch day {
        case ...5: return .menstrual
        case 6..<(ovulationDay - 1): return .follicular
        case (ovulationDay - 1)...(ovulationDay + 1): return .ovulatory
        default: return .luteal
        }
    }

    /// How many cycles of history inform the prediction (drives the "sharpens as you log" message).
    public var loggedCycleCount: Int { max(sortedStarts.count - 1, 0) }

    // MARK: - Mutations

    public func completeOnboarding(profile: UserProfile, lastPeriodStart: Date?) {
        self.profile = profile
        if let start = lastPeriodStart {
            addPeriod(start: start, flow: nil)
        }
        hasOnboarded = true
    }

    @discardableResult
    public func addPeriod(start: Date, end: Date? = nil, flow: FlowIntensity? = nil) -> PeriodRecord {
        let record = PeriodRecord(
            sync: SyncMetadata(deviceID: deviceID),
            startDate: Calendar.current.startOfDay(for: start),
            endDate: end,
            flow: flow
        )
        periods.append(record)
        periods.sort { $0.startDate < $1.startDate }
        return record
    }

    public func deletePeriod(id: UUID) {
        periods.removeAll { $0.id == id }
    }

    /// True if a period start is already logged on the given calendar day.
    public func hasPeriod(on day: Date) -> Bool {
        let target = Calendar.current.startOfDay(for: day)
        return periods.contains { Calendar.current.isDate($0.startDate, inSameDayAs: target) }
    }

    /// Toggle a period start on a day (used by the calendar tap).
    public func togglePeriod(on day: Date) {
        let target = Calendar.current.startOfDay(for: day)
        if let existing = periods.first(where: { Calendar.current.isDate($0.startDate, inSameDayAs: target) }) {
            deletePeriod(id: existing.id)
        } else {
            addPeriod(start: target, flow: .medium)
        }
    }
}
