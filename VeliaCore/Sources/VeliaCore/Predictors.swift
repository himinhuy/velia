import Foundation

// MARK: - Predictor protocol

public protocol CyclePredictor: Sendable {
    /// Predict the next period (and ovulation) given history up to `asOf`.
    func predict(history: [PeriodEvent], profile: UserProfile, asOf: Date) -> Prediction
}

// MARK: - Shared helpers

enum CycleDerivation {
    /// Cycle lengths (days) = gaps between consecutive period starts, oldest→newest.
    static func lengths(from history: [PeriodEvent]) -> [Double] {
        let starts = history.map(\.startDate).sorted()
        guard starts.count >= 2 else { return [] }
        return zip(starts.dropLast(), starts.dropFirst()).map { DayMath.daysBetween($0, $1) }
    }

    static func lastStart(_ history: [PeriodEvent]) -> Date? {
        history.map(\.startDate).max()
    }

    static func window(point: Date, halfWidth: Double) -> DateInterval {
        DateInterval(start: DayMath.add(days: -halfWidth, to: point),
                     end: DayMath.add(days: halfWidth, to: point))
    }
}

// MARK: - Baseline 1: Naive 28-day

public struct Naive28Predictor: CyclePredictor {
    public init() {}
    public func predict(history: [PeriodEvent], profile: UserProfile, asOf: Date) -> Prediction {
        let last = CycleDerivation.lastStart(history) ?? asOf
        let point = DayMath.add(days: 28, to: last)
        return Prediction(
            nextPeriod: CycleDerivation.window(point: point, halfWidth: 2),
            ovulation: CycleDerivation.window(point: DayMath.add(days: 28 - 14, to: last), halfWidth: 2),
            cyclePhase: .unknown, confidence: .low, mode: .normal, intervalCoverageTarget: 0.80)
    }
}

// MARK: - Baseline 2: Simple average of past cycle lengths

public struct SimpleAveragePredictor: CyclePredictor {
    public init() {}
    public func predict(history: [PeriodEvent], profile: UserProfile, asOf: Date) -> Prediction {
        let lengths = CycleDerivation.lengths(from: history)
        let last = CycleDerivation.lastStart(history) ?? asOf
        let mean = lengths.isEmpty ? Double(profile.typicalCycleLength ?? 28) : Stats.mean(lengths)
        let sd = max(Stats.stddev(lengths), 1)
        let half = Stats.normalQuantile(0.90) * sd
        let point = DayMath.add(days: mean, to: last)
        return Prediction(
            nextPeriod: CycleDerivation.window(point: point, halfWidth: half),
            ovulation: CycleDerivation.window(point: DayMath.add(days: mean - 14, to: last), halfWidth: half * 1.3),
            cyclePhase: .unknown, confidence: .low, mode: .normal, intervalCoverageTarget: 0.80)
    }
}

// MARK: - The moat: recency-weighted, skip-aware Bayesian predictor

public struct BayesianCyclePredictor: CyclePredictor {
    public var decay: Double            // recency weight per cycle of age
    public var coverageTarget: Double   // two-sided interval coverage, e.g. 0.80
    public var skipDownWeight: Double   // weight applied to suspected anovulatory cycles
    public var honestyWidthDays: Double // interval wider than this ⇒ "too irregular"
    public var varianceFloor: Double    // minimum process variance (days²)

    public init(decay: Double = 0.82,
                coverageTarget: Double = 0.80,
                skipDownWeight: Double = 0.12,
                honestyWidthDays: Double = 22,
                varianceFloor: Double = 1.5) {
        self.decay = decay
        self.coverageTarget = coverageTarget
        self.skipDownWeight = skipDownWeight
        self.honestyWidthDays = honestyWidthDays
        self.varianceFloor = varianceFloor
    }

    public func predict(history: [PeriodEvent], profile: UserProfile, asOf: Date) -> Prediction {
        let prior = SegmentPrior.forProfile(profile)
        let lengths = CycleDerivation.lengths(from: history)
        let last = CycleDerivation.lastStart(history) ?? asOf

        // Cold start: no observed cycles → predict from the prior alone, honestly wide.
        guard !lengths.isEmpty else {
            return makePrediction(predMean: prior.mean,
                                  predSD: prior.sd,
                                  df: 3,
                                  last: last,
                                  forcedMode: prior.sd > 8 ? .tooIrregularToPredict : .normal)
        }

        // 1) Skip/anovulatory detection relative to the user's own median.
        let userMedian = Stats.median(lengths)
        let threshold = prior.skipThreshold(userMedian: userMedian)

        // 2) Recency + skip weighting (most recent cycle = highest weight).
        let n = lengths.count
        var weights = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let age = Double(n - 1 - i)               // 0 == most recent
            let recency = pow(decay, age)
            let isSkip = lengths[i] > threshold
            weights[i] = recency * (isSkip ? skipDownWeight : 1.0)
        }

        // 3) Weighted mean/variance + effective sample size.
        let w = Stats.weighted(values: lengths, weights: weights)
        let obsVar = max(w.variance, varianceFloor)

        // 4) Normal–Normal posterior on the mean (prior precision + data precision).
        let priorVar = prior.sd * prior.sd
        let priorPrecision = 1.0 / priorVar
        let dataPrecision = w.effectiveN / obsVar
        let postPrecision = priorPrecision + dataPrecision
        let postMean = (prior.mean * priorPrecision + w.mean * dataPrecision) / postPrecision
        let postVar = 1.0 / postPrecision

        // 5) Predictive distribution for the *next* cycle length.
        let predVar = obsVar + postVar
        let predSD = predVar.squareRoot()
        let df = max(w.effectiveN - 1, 3)

        return makePrediction(predMean: postMean, predSD: predSD, df: df, last: last, forcedMode: nil)
    }

    private func makePrediction(predMean: Double, predSD: Double, df: Double,
                                last: Date, forcedMode: PredictionMode?) -> Prediction {
        let q = Stats.tQuantile((1 + coverageTarget) / 2, df: df)
        let half = q * predSD
        let point = DayMath.add(days: predMean, to: last)
        let width = 2 * half

        let mode: PredictionMode = forcedMode ?? (width > honestyWidthDays ? .tooIrregularToPredict : .normal)

        let confidence: ConfidenceLevel
        switch width {
        case ..<5:  confidence = .high
        case ..<10: confidence = .moderate
        default:    confidence = .low
        }

        // Ovulation ≈ cycleLength − luteal(14), with a wider interval; suppressed when too uncertain.
        let ovHalf = half * 1.4
        let ovulation: DateInterval? = (mode == .tooIrregularToPredict || predSD > 6)
            ? nil
            : CycleDerivation.window(point: DayMath.add(days: predMean - 14, to: last), halfWidth: ovHalf)

        return Prediction(nextPeriod: CycleDerivation.window(point: point, halfWidth: half),
                          ovulation: ovulation,
                          cyclePhase: .luteal,
                          confidence: confidence,
                          mode: mode,
                          intervalCoverageTarget: coverageTarget)
    }
}
