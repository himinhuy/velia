import Foundation

// MARK: - Synthetic dataset

//
// Stand-in for the public irregular-cycle benchmark dataset (Phase 0, milestone 0.2).
// Generates realistic per-segment cycle sequences with trends and anovulatory skips so the
// engine can be exercised before the real dataset is licensed/loaded. Deterministic via seed.

/// A single subject in a benchmark dataset (synthetic or real).
public struct BenchmarkUser: Sendable {
    public let segment: Segment
    public let history: [PeriodEvent] // chronological period starts
    public let isIrregular: Bool

    public init(segment: Segment, history: [PeriodEvent], isIrregular: Bool) {
        self.segment = segment
        self.history = history
        self.isIrregular = isIrregular
    }
}

/// Back-compat alias.
public typealias SyntheticUser = BenchmarkUser

public enum SyntheticDataset {
    public static func generate(
        seed: UInt64 = 42,
        usersPerSegment: Int = 60,
        cyclesPerUser: Int = 16
    ) -> [BenchmarkUser] {
        var rng = SeededRNG(seed: seed)
        // Midnight UTC (2020-09-13) so generated dates are exactly representable as yyyy-MM-dd.
        let epoch = Date(timeIntervalSince1970: 1_599_955_200)
        var users: [BenchmarkUser] = []

        let segments: [Segment] = [.typical, .pcos, .perimenopause, .postpartum]
        for segment in segments {
            for _ in 0 ..< usersPerSegment {
                let lengths = generateLengths(segment: segment, count: cyclesPerUser, rng: &rng)
                var starts: [Date] = [epoch]
                for len in lengths {
                    starts.append(DayMath.add(days: len, to: starts.last!))
                }
                let history = starts.map { PeriodEvent(startDate: $0) }
                let irregular = segment != .typical
                users.append(BenchmarkUser(segment: segment, history: history, isIrregular: irregular))
            }
        }
        return users
    }

    /// Parameters are calibrated to published distributions so the synthetic irregular cohort is a
    /// defensible stand-in until real PCOS-rich data is available (see docs/data-sources.md §1):
    ///   • Typical:  Bull 2019 — population mean 29.3±5.2 d (between-person + within-person).
    ///   • PCOS:     Apple WHS 2025 — mean ~33–36 d, within-person SD 8–11 d.
    ///   • Perimeno: STRAW+10 — lengthening + persistent ≥7-day variability.
    ///   • Postpartum: long early cycles recovering toward typical.
    private static func generateLengths(segment: Segment, count: Int, rng: inout SeededRNG) -> [Double] {
        var out: [Double] = []
        switch segment {
        case .typical:
            // Between-person mean spread + small within-person variation.
            let userMean = rng.gaussian(mean: 29, sd: 3)
            for _ in 0 ..< count {
                out.append(clamp(rng.gaussian(mean: userMean, sd: 2.2)))
            }
        case .pcos:
            let userMean = clamp(rng.gaussian(mean: 33, sd: 4), lo: 27, hi: 46)
            for _ in 0 ..< count {
                var len = rng.gaussian(mean: userMean, sd: 6) // base within-person spread
                if Double.random(in: 0 ..< 1, using: &rng) < 0.12 { // anovulatory skip → long cycle
                    len += rng.gaussian(mean: 26, sd: 6)
                }
                out.append(clamp(len, lo: 18, hi: 110))
            }
        case .perimenopause:
            var base = rng.gaussian(mean: 27, sd: 2)
            for _ in 0 ..< count {
                base += 0.7 // lengthening trend
                var len = rng.gaussian(mean: base, sd: 4 + base * 0.07)
                if Double.random(in: 0 ..< 1, using: &rng) < 0.15 { len += rng.gaussian(mean: 28, sd: 6) }
                out.append(clamp(len, lo: 18, hi: 110))
            }
        case .postpartum:
            var base = rng.gaussian(mean: 48, sd: 4)
            for _ in 0 ..< count {
                base = max(29, base - 1.6) // recovery toward typical
                out.append(clamp(rng.gaussian(mean: base, sd: 5), lo: 20, hi: 110))
            }
        case .unknown:
            let userMean = rng.gaussian(mean: 30, sd: 4)
            for _ in 0 ..< count {
                out.append(clamp(rng.gaussian(mean: userMean, sd: 5)))
            }
        }
        return out
    }

    private static func clamp(_ x: Double, lo: Double = 18, hi: Double = 90) -> Double {
        min(max(x.rounded(), lo), hi)
    }

    static func profile(for segment: Segment) -> UserProfile {
        UserProfile(birthYear: nil, typicalCycleLength: nil, segment: segment)
    }
}

// MARK: - Irregularity classification (for unlabeled real datasets)

public extension BenchmarkUser {
    /// Within-person standard deviation of cycle lengths in days (0 if < 2 cycles).
    var cycleLengthSD: Double {
        Stats.stddev(CycleDerivation.lengths(from: history))
    }
}

/// Classifies users as irregular from their *observed* cycle variability rather than a clinical
/// label — needed for open datasets (e.g. FedCycle) that have no PCOS/perimenopause labels.
public enum IrregularityClassifier {
    /// STRAW+10: persistent ≥7-day changes in cycle length mark the menopausal transition / irregularity.
    public static let strawThresholdDays = 7.0

    public static func apply(_ users: [BenchmarkUser], sdThreshold: Double = strawThresholdDays) -> [BenchmarkUser] {
        users.map {
            BenchmarkUser(segment: $0.segment, history: $0.history, isIrregular: $0.cycleLengthSD >= sdThreshold)
        }
    }
}

// MARK: - Benchmark runner

public struct BenchmarkMetrics: Sendable {
    public let predictor: String
    public let subset: String
    public let count: Int
    public let medianAbsError: Double // days
    public let meanAbsError: Double // days
    public let coverage: Double // empirical fraction inside interval
    public let coverageTarget: Double
}

public enum Benchmark {
    /// Walk each user cycle-by-cycle: from index `minHistory`, predict the next cycle, compare to actual.
    public static func evaluate(
        predictor: CyclePredictor,
        name: String,
        users: [BenchmarkUser],
        onlyIrregular: Bool,
        minHistory: Int = 3
    ) -> BenchmarkMetrics {
        var absErrors: [Double] = []
        var inside = 0
        var total = 0
        var coverageTarget = 0.80

        for user in users where !onlyIrregular || user.isIrregular {
            let starts = user.history.map(\.startDate).sorted()
            guard starts.count > minHistory + 1 else { continue }
            let profile = SyntheticDataset.profile(for: user.segment)

            for i in minHistory ..< (starts.count - 1) {
                let hist = Array(user.history.prefix(i + 1)) // starts[0...i]
                let actualNext = starts[i + 1]
                let pred = predictor.predict(history: hist, profile: profile, asOf: starts[i])
                coverageTarget = pred.intervalCoverageTarget

                let err = abs(DayMath.daysBetween(actualNext, pred.pointDate))
                absErrors.append(err)
                total += 1
                if actualNext >= pred.nextPeriod.start, actualNext <= pred.nextPeriod.end { inside += 1 }
            }
        }

        return BenchmarkMetrics(
            predictor: name,
            subset: onlyIrregular ? "irregular" : "all",
            count: total,
            medianAbsError: Stats.median(absErrors),
            meanAbsError: Stats.mean(absErrors),
            coverage: total > 0 ? Double(inside) / Double(total) : .nan,
            coverageTarget: coverageTarget
        )
    }
}
