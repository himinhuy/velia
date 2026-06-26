import Foundation

// MARK: - Domain models (pure value types)

/// A logged menstruation event. The engine derives cycles from the sequence of starts.
public struct PeriodEvent: Sendable, Equatable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?

    public init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// User's known reproductive segment, used to pick a cold-start prior.
public enum Segment: String, Sendable, CaseIterable {
    case typical
    case pcos
    case perimenopause
    case postpartum
    case unknown
}

/// Onboarding intake. `typicalCycleLength` (if provided) refines the segment prior.
public struct UserProfile: Sendable, Equatable {
    public let birthYear: Int?
    public let typicalCycleLength: Int?
    public let segment: Segment

    public init(birthYear: Int? = nil, typicalCycleLength: Int? = nil, segment: Segment = .unknown) {
        self.birthYear = birthYear
        self.typicalCycleLength = typicalCycleLength
        self.segment = segment
    }
}

public enum CyclePhase: String, Sendable {
    case menstrual, follicular, ovulatory, luteal, unknown
}

public enum ConfidenceLevel: String, Sendable {
    case high, moderate, low
}

public enum PredictionMode: String, Sendable {
    case normal
    case tooIrregularToPredict
}

/// Engine output. The interval *is* the calibrated confidence range (no false precision).
public struct Prediction: Sendable, Equatable {
    public let nextPeriod: DateInterval
    public let ovulation: DateInterval?
    public let cyclePhase: CyclePhase
    public let confidence: ConfidenceLevel
    public let mode: PredictionMode
    /// Two-sided coverage the interval is calibrated for, e.g. 0.80.
    public let intervalCoverageTarget: Double

    public init(
        nextPeriod: DateInterval,
        ovulation: DateInterval?,
        cyclePhase: CyclePhase,
        confidence: ConfidenceLevel,
        mode: PredictionMode,
        intervalCoverageTarget: Double
    ) {
        self.nextPeriod = nextPeriod
        self.ovulation = ovulation
        self.cyclePhase = cyclePhase
        self.confidence = confidence
        self.mode = mode
        self.intervalCoverageTarget = intervalCoverageTarget
    }

    /// Midpoint of the predicted period window (point estimate for error metrics).
    public var pointDate: Date {
        Date(timeIntervalSince1970:
            (nextPeriod.start.timeIntervalSince1970 + nextPeriod.end.timeIntervalSince1970) / 2)
    }
}

// MARK: - Date helpers

public enum DayMath {
    public static let secondsPerDay: TimeInterval = 86400

    public static func add(days: Double, to date: Date) -> Date {
        date.addingTimeInterval(days * secondsPerDay)
    }

    public static func daysBetween(_ a: Date, _ b: Date) -> Double {
        b.timeIntervalSince(a) / secondsPerDay
    }
}
