import Foundation
import VeliaCore

// Phase 0 gate runner. See docs/phases/phase-0-prediction-engine-gate.md.
// Usage:
//   swift run velia-bench [seed]            # synthetic data (default seed 42)
//   swift run velia-bench --csv <path>      # real dataset (CSV: user_id,segment,period_start)

let args = CommandLine.arguments

// Export a correctly-shaped synthetic CSV (a starter/template you can inspect or run).
//   swift run velia-bench --export-csv <path> [usersPerSegment]
if let i = args.firstIndex(of: "--export-csv"), i + 1 < args.count {
    let path = args[i + 1]
    let perSegment = (i + 2 < args.count ? Int(args[i + 2]) : nil) ?? 60
    let data = SyntheticDataset.generate(usersPerSegment: perSegment)
    do {
        try CSVCycleDataset.serialize(data).write(toFile: path, atomically: true, encoding: .utf8)
        print("Wrote \(data.count) users to \(path) (\(perSegment)/segment).")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Failed to write \(path): \(error)\n".utf8))
        exit(2)
    }
}

let loadedUsers: [BenchmarkUser]
var sourceLabel: String

if let i = args.firstIndex(of: "--csv"), i + 1 < args.count {
    let path = args[i + 1]
    do {
        loadedUsers = try CSVCycleDataset(url: URL(fileURLWithPath: path)).load()
        sourceLabel = "CSV: \(path)"
    } catch {
        FileHandle.standardError.write(Data("Failed to load CSV \(path): \(error)\n".utf8))
        exit(2)
    }
} else {
    let seed = args.count > 1 ? (UInt64(args[1]) ?? 42) : 42
    loadedUsers = SyntheticDataset.generate(seed: seed)
    sourceLabel = "synthetic (seed \(seed))"
}

/// For unlabeled datasets, derive the "irregular" subset from observed cycle variability.
let users: [BenchmarkUser]
if let i = args.firstIndex(of: "--irregular-from-data") {
    let thr = (i + 1 < args.count ? Double(args[i + 1]) : nil) ?? IrregularityClassifier.strawThresholdDays
    users = IrregularityClassifier.apply(loadedUsers, sdThreshold: thr)
    sourceLabel += " | irregular = within-person SD ≥ \(thr)d"
} else {
    users = loadedUsers
}

let predictors: [(String, CyclePredictor)] = [
    ("Naive28", Naive28Predictor()),
    ("SimpleAvg", SimpleAveragePredictor()),
    ("Bayesian", BayesianCyclePredictor())
]

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}

func fmt(_ x: Double) -> String {
    String(format: "%6.2f", x)
}

print("Velia — Phase 0 engine benchmark [\(sourceLabel)]")
print("Users: \(users.count) | irregular: \(users.filter(\.isIrregular).count)\n")

func table(onlyIrregular: Bool) -> [String: BenchmarkMetrics] {
    let title = onlyIrregular ? "IRREGULAR SUBSET (PCOS / perimenopause / postpartum)" : "ALL USERS"
    print("== \(title) ==")
    print(pad("predictor", 12) + pad("n", 7) + pad("medAE", 8) + pad("meanAE", 8) + pad("coverage", 12))
    var results: [String: BenchmarkMetrics] = [:]
    for (name, p) in predictors {
        let m = Benchmark.evaluate(predictor: p, name: name, users: users, onlyIrregular: onlyIrregular)
        results[name] = m
        let cov = "\(fmt(m.coverage * 100))% / \(Int(m.coverageTarget * 100))%"
        print(pad(name, 12) + pad("\(m.count)", 7) + pad(fmt(m.medianAbsError), 8)
            + pad(fmt(m.meanAbsError), 8) + pad(cov, 12))
    }
    print("")
    return results
}

_ = table(onlyIrregular: false)
let irr = table(onlyIrregular: true)

// ---- Gate evaluation (thresholds mirror phase-0 checkpoint) ----
let bayes = irr["Bayesian"]!
let beatsNaive = bayes.medianAbsError < irr["Naive28"]!.medianAbsError
let beatsAvg = bayes.medianAbsError < irr["SimpleAvg"]!.medianAbsError
let calibrationTol = 0.08
let wellCalibrated = abs(bayes.coverage - bayes.coverageTarget) <= calibrationTol

print("== GATE ==")
print("[\(beatsNaive ? "PASS" : "FAIL")] Bayesian beats Naive28 on irregular median AE "
    + "(\(fmt(bayes.medianAbsError)) < \(fmt(irr["Naive28"]!.medianAbsError)))")
print("[\(beatsAvg ? "PASS" : "FAIL")] Bayesian beats SimpleAvg on irregular median AE "
    + "(\(fmt(bayes.medianAbsError)) < \(fmt(irr["SimpleAvg"]!.medianAbsError)))")
print("[\(wellCalibrated ? "PASS" : "FAIL")] Interval calibration within ±\(Int(calibrationTol * 100))pp of target "
    + "(\(fmt(bayes.coverage * 100))% vs \(Int(bayes.coverageTarget * 100))%)")

let go = beatsNaive && beatsAvg && wellCalibrated
print("\nDECISION: \(go ? "GO ✅" : "NO-GO ❌")")
exit(go ? 0 : 1)
