import Foundation
import Observation
import VeliaCore

/// App-wide observable state + the bridge to the on-device prediction engine.
///
/// **Per-day model.** Each logged period day is one `PeriodRecord`. Contiguous days form a "run"
/// (one menstrual period); the engine derives cycles from the *start of each run*. This lets the
/// calendar draw multi-day bands and makes every day independently toggleable (nothing is a
/// one-shot irreversible tap).
///
/// **In-memory only by design.** Logged data is PHI; architecture §0 invariant #3 requires it
/// encrypted at rest (SQLCipher), which lands when VeliaData is wired (Phase 1 finish). Until then
/// we keep everything in RAM rather than writing plaintext PHI to disk — data resets on cold launch.
@MainActor
@Observable
public final class CycleStore {
    public private(set) var profile: UserProfile
    /// One record per logged period *day*.
    public private(set) var periodDays: [PeriodRecord]
    /// Feelings / pain / other day-level symptoms.
    public private(set) var symptoms: [SymptomRecord]
    public var hasOnboarded: Bool
    /// Typical bleeding length in days (used for the ring; not part of the engine prior).
    public private(set) var typicalPeriodLength: Int
    /// Tracking intent — a non-destructive UI lens over the same data.
    public private(set) var mode: TrackingMode
    /// Manual fertility signals (BBT / cervical mucus / LH) — used in conceive mode.
    public private(set) var fertility: [FertilityRecord]

    private let predictor = BayesianCyclePredictor()
    private let deviceID = UUID()
    private let cal = Calendar.current
    private let persistence: CyclePersistence?

    public init(profile: UserProfile = UserProfile(),
                periodDays: [PeriodRecord] = [],
                symptoms: [SymptomRecord] = [],
                hasOnboarded: Bool = false,
                typicalPeriodLength: Int = 5,
                mode: TrackingMode = .period,
                fertility: [FertilityRecord] = [],
                persistence: CyclePersistence? = nil) {
        self.profile = profile
        self.periodDays = periodDays
        self.symptoms = symptoms
        self.hasOnboarded = hasOnboarded
        self.typicalPeriodLength = typicalPeriodLength
        self.mode = mode
        self.fertility = fertility
        self.persistence = persistence

        if let saved = persistence?.load() {
            self.profile = UserProfile(birthYear: saved.birthYear,
                                       typicalCycleLength: saved.typicalCycleLength,
                                       segment: Segment(rawValue: saved.segmentRaw) ?? .unknown)
            self.periodDays = saved.periodDays
            self.symptoms = saved.symptoms
            self.hasOnboarded = saved.hasOnboarded
            self.typicalPeriodLength = saved.typicalPeriodLength
            self.mode = saved.modeRaw.flatMap(TrackingMode.init(rawValue:)) ?? .period
            self.fertility = saved.fertility ?? []
        }
    }

    /// Persist current state (encrypted). Called after every mutation.
    private func persist() {
        persistence?.save(PersistedState(
            hasOnboarded: hasOnboarded,
            birthYear: profile.birthYear,
            typicalCycleLength: profile.typicalCycleLength,
            typicalPeriodLength: typicalPeriodLength,
            segmentRaw: profile.segment.rawValue,
            periodDays: periodDays,
            symptoms: symptoms,
            modeRaw: mode.rawValue,
            fertility: fertility
        ))
    }

    // MARK: - Derived: runs → cycle starts

    /// Sorted unique day-starts that have a logged period.
    private var loggedDays: [Date] {
        Set(periodDays.map { cal.startOfDay(for: $0.startDate) }).sorted()
    }

    /// Contiguous runs of period days, oldest → newest. Each run is one menstrual period.
    public func periodRuns() -> [ClosedRange<Date>] {
        let days = loggedDays
        guard !days.isEmpty else { return [] }
        var runs: [ClosedRange<Date>] = []
        var runStart = days[0]
        var prev = days[0]
        for day in days.dropFirst() {
            if let next = cal.date(byAdding: .day, value: 1, to: prev), cal.isDate(day, inSameDayAs: next) {
                prev = day
            } else {
                runs.append(runStart...prev)
                runStart = day
                prev = day
            }
        }
        runs.append(runStart...prev)
        return runs
    }

    /// Cycle starts = first day of each run.
    public var cycleStarts: [Date] { periodRuns().map(\.lowerBound) }

    public var lastPeriodStart: Date? { cycleStarts.last }

    private var history: [PeriodEvent] {
        cycleStarts.map { PeriodEvent(startDate: $0) }
    }

    /// The calibrated on-device prediction. Nil when there's no history, or in modes that don't
    /// forecast a cycle (e.g. track-without-period) — we never fake a prediction.
    public var prediction: Prediction? {
        guard mode.predictsCycle, !history.isEmpty else { return nil }
        return predictor.predict(history: history, profile: profile, asOf: lastPeriodStart ?? Date())
    }

    /// 1-based day of the current cycle.
    public func cycleDay(asOf now: Date = Date()) -> Int? {
        guard let last = lastPeriodStart else { return nil }
        let days = Int(DayMath.daysBetween(last, now).rounded(.down))
        return max(days + 1, 1)
    }

    /// Coarse display phase for the header (the engine owns the predictive outputs; this is a label).
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

    /// Number of complete cycles informing the prediction (drives the "sharpens as you log" copy).
    public var loggedCycleCount: Int { max(periodRuns().count - 1, 0) }

    // MARK: - Cycle statistics (for the Analysis screen)

    /// Observed cycle lengths in days (gaps between consecutive run starts).
    public var observedCycleLengths: [Int] {
        let starts = cycleStarts
        guard starts.count >= 2 else { return [] }
        return zip(starts.dropLast(), starts.dropFirst())
            .map { Int(DayMath.daysBetween($0, $1).rounded()) }
    }

    public var averageCycleLength: Int? {
        let v = observedCycleLengths
        guard !v.isEmpty else { return nil }
        return Int((Double(v.reduce(0, +)) / Double(v.count)).rounded())
    }

    // MARK: - Period day mutations

    public func isPeriodDay(on day: Date) -> Bool {
        let target = cal.startOfDay(for: day)
        return periodDays.contains { cal.isDate($0.startDate, inSameDayAs: target) }
    }

    public func flow(on day: Date) -> FlowIntensity? {
        let target = cal.startOfDay(for: day)
        return periodDays.first { cal.isDate($0.startDate, inSameDayAs: target) }?.flow
    }

    /// Set (or clear, when `flow == nil`) the period flow for a single day.
    public func setFlow(on day: Date, flow: FlowIntensity?) {
        let target = cal.startOfDay(for: day)
        if let flow {
            if let idx = periodDays.firstIndex(where: { cal.isDate($0.startDate, inSameDayAs: target) }) {
                periodDays[idx].flow = flow
            } else {
                periodDays.append(PeriodRecord(sync: SyncMetadata(deviceID: deviceID),
                                               startDate: target, endDate: target, flow: flow))
                periodDays.sort { $0.startDate < $1.startDate }
            }
        } else {
            periodDays.removeAll { cal.isDate($0.startDate, inSameDayAs: target) }
        }
        persist()
    }

    /// Convenience used by tests/seed: mark a single day as a period day.
    @discardableResult
    public func addPeriod(start: Date, flow: FlowIntensity? = .medium) -> Date {
        let day = cal.startOfDay(for: start)
        setFlow(on: day, flow: flow ?? .medium)
        return day
    }

    public func deletePeriodDay(on day: Date) { setFlow(on: day, flow: nil) }

    public func togglePeriod(on day: Date) {
        setFlow(on: day, flow: isPeriodDay(on: day) ? nil : .medium)
    }

    // MARK: - Symptom mutations

    public func isSymptomSelected(_ category: String, _ id: String, on day: Date) -> Bool {
        let target = cal.startOfDay(for: day)
        return symptoms.contains {
            $0.type == category && $0.note == id && cal.isDate($0.date, inSameDayAs: target)
        }
    }

    public func toggleSymptom(_ category: String, _ id: String, on day: Date) {
        let target = cal.startOfDay(for: day)
        if let idx = symptoms.firstIndex(where: {
            $0.type == category && $0.note == id && cal.isDate($0.date, inSameDayAs: target)
        }) {
            symptoms.remove(at: idx)
        } else {
            symptoms.append(SymptomRecord(sync: SyncMetadata(deviceID: deviceID),
                                          date: target, type: category, value: 1, note: id))
        }
        persist()
    }

    /// Single-choice categories (energy, sleep, sex): selecting one clears the others in that
    /// category on the same day. Tapping the selected one again clears it.
    public func selectExclusiveSymptom(_ category: String, _ id: String, on day: Date) {
        let target = cal.startOfDay(for: day)
        let already = isSymptomSelected(category, id, on: day)
        symptoms.removeAll { $0.type == category && cal.isDate($0.date, inSameDayAs: target) }
        if !already {
            symptoms.append(SymptomRecord(sync: SyncMetadata(deviceID: deviceID),
                                          date: target, type: category, value: 1, note: id))
        }
        persist()
    }

    /// Free-text note for a day, stored as a `SymptomRecord(type: "note")`.
    public func note(on day: Date) -> String {
        let target = cal.startOfDay(for: day)
        return symptoms.first {
            $0.type == "note" && cal.isDate($0.date, inSameDayAs: target)
        }?.note ?? ""
    }

    public func setNote(_ text: String, on day: Date) {
        let target = cal.startOfDay(for: day)
        symptoms.removeAll { $0.type == "note" && cal.isDate($0.date, inSameDayAs: target) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            symptoms.append(SymptomRecord(sync: SyncMetadata(deviceID: deviceID),
                                          date: target, type: "note", value: 0, note: trimmed))
        }
        persist()
    }

    /// Whether any data (period or symptom) is logged on a day — for calendar dots.
    public func hasAnyLog(on day: Date) -> Bool {
        let target = cal.startOfDay(for: day)
        return isPeriodDay(on: day) || symptoms.contains { cal.isDate($0.date, inSameDayAs: target) }
            || fertility.contains { cal.isDate($0.date, inSameDayAs: target) }
    }

    // MARK: - Fertility signals (conceive mode)

    public func fertilityEntry(on day: Date) -> FertilityRecord? {
        let target = cal.startOfDay(for: day)
        return fertility.first { cal.isDate($0.date, inSameDayAs: target) }
    }

    /// Set/clear a fertility signal for a day. Passing all-nil removes the entry.
    public func setFertility(on day: Date, bbtCelsius: Double?, cervicalMucus: String?, lhTest: String?) {
        let target = cal.startOfDay(for: day)
        fertility.removeAll { cal.isDate($0.date, inSameDayAs: target) }
        if bbtCelsius != nil || cervicalMucus != nil || lhTest != nil {
            fertility.append(FertilityRecord(sync: SyncMetadata(deviceID: deviceID),
                                             date: target, bbtCelsius: bbtCelsius,
                                             cervicalMucus: cervicalMucus, lhTest: lhTest))
        }
        persist()
    }

    // MARK: - Mode

    public func setMode(_ newMode: TrackingMode) {
        guard newMode.isFunctional else { return }
        mode = newMode
        persist()
    }

    // MARK: - Profile

    public func completeOnboarding(mode: TrackingMode = .period, profile: UserProfile,
                                   lastPeriodStart: Date?, periodLength: Int = 5) {
        self.mode = mode.isFunctional ? mode : .period
        self.profile = profile
        self.typicalPeriodLength = min(max(periodLength, 1), 10)
        if let start = lastPeriodStart {
            // Seed the most recent period as a run of `periodLength` days for an accurate ring.
            let day0 = cal.startOfDay(for: start)
            for offset in 0..<typicalPeriodLength {
                if let d = cal.date(byAdding: .day, value: offset, to: day0), d <= Date() {
                    addPeriod(start: d, flow: .medium)
                }
            }
        }
        hasOnboarded = true
        persist()
    }

    public func updateProfile(typicalCycleLength: Int, segment: Segment, birthYear: Int?, periodLength: Int) {
        profile = UserProfile(birthYear: birthYear,
                              typicalCycleLength: typicalCycleLength,
                              segment: segment)
        typicalPeriodLength = min(max(periodLength, 1), 10)
        persist()
    }
}
