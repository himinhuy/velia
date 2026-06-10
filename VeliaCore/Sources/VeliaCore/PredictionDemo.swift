import Foundation

/// A self-contained, deterministic prediction built from sample history — gives the app real,
/// on-device content to render for manual testing before tracking/storage UI exists (Phases 2–3).
/// Pure & tested so the UI layer only renders.
public enum PredictionDemo {

    /// Six recent cycles ending just before `asOf`, so the prediction points at the near future.
    public static func sampleHistory(asOf: Date = Date()) -> [PeriodEvent] {
        let lengths: [Double] = [29, 28, 30, 27, 29, 28]
        let total = lengths.reduce(0, +)
        var start = DayMath.add(days: -(total + 14), to: asOf)
        var events: [PeriodEvent] = [PeriodEvent(startDate: start)]
        for length in lengths {
            start = DayMath.add(days: length, to: start)
            events.append(PeriodEvent(startDate: start))
        }
        return events
    }

    public static func sample(asOf: Date = Date()) -> Prediction {
        let history = sampleHistory(asOf: asOf)
        let last = history.map(\.startDate).max() ?? asOf
        let profile = UserProfile(typicalCycleLength: 29, segment: .typical)
        return BayesianCyclePredictor().predict(history: history, profile: profile, asOf: last)
    }

    /// Human-readable summary for a quick on-screen check.
    public static func sampleSummary(asOf: Date = Date()) -> String {
        let p = sample(asOf: asOf)
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let lo = df.string(from: p.nextPeriod.start)
        let hi = df.string(from: p.nextPeriod.end)
        switch p.mode {
        case .normal:
            return "Next period likely \(lo)–\(hi) · confidence: \(p.confidence.rawValue)"
        case .tooIrregularToPredict:
            return "Cycle too irregular to predict confidently — estimated \(lo)–\(hi)"
        }
    }
}
