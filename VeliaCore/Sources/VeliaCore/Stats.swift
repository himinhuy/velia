import Foundation

// MARK: - Statistics utilities (deterministic, testable)

public enum Stats {

    /// Robust median.
    public static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return .nan }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    public static func mean(_ xs: [Double]) -> Double {
        xs.isEmpty ? .nan : xs.reduce(0, +) / Double(xs.count)
    }

    /// Sample standard deviation (unbiased). Returns 0 for < 2 elements.
    public static func stddev(_ xs: [Double]) -> Double {
        guard xs.count > 1 else { return 0 }
        let m = mean(xs)
        let ss = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (ss / Double(xs.count - 1)).squareRoot()
    }

    public struct Weighted {
        public let mean: Double
        public let variance: Double
        /// Kish effective sample size: (Σw)² / Σw².
        public let effectiveN: Double
    }

    /// Weighted mean + unbiased weighted variance (reliability weights) + effective N.
    public static func weighted(values: [Double], weights: [Double]) -> Weighted {
        precondition(values.count == weights.count)
        let sumW = weights.reduce(0, +)
        guard sumW > 0 else { return Weighted(mean: .nan, variance: 0, effectiveN: 0) }
        let sumW2 = weights.reduce(0) { $0 + $1 * $1 }
        let m = zip(values, weights).reduce(0) { $0 + $1.0 * $1.1 } / sumW
        let denom = sumW - sumW2 / sumW
        var v = 0.0
        if denom > 0 {
            let ss = zip(values, weights).reduce(0) { $0 + $1.1 * ($1.0 - m) * ($1.0 - m) }
            v = ss / denom
        }
        let nEff = (sumW * sumW) / sumW2
        return Weighted(mean: m, variance: v, effectiveN: nEff)
    }

    /// Inverse standard-normal CDF (Acklam's algorithm).
    public static func normalQuantile(_ p: Double) -> Double {
        precondition(p > 0 && p < 1)
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                 3.754408661907416e+00]
        let plow = 0.02425, phigh = 1 - 0.02425
        if p < plow {
            let q = (-2 * Foundation.log(p)).squareRoot()
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                   ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= phigh {
            let q = p - 0.5, r = q * q
            return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
                   (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = (-2 * Foundation.log(1 - p)).squareRoot()
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
    }

    /// Student-t quantile via Cornish-Fisher expansion of the normal quantile (good for df ≥ 3).
    public static func tQuantile(_ p: Double, df: Double) -> Double {
        let z = normalQuantile(p)
        let df1 = max(df, 3)
        let g1 = (pow(z, 3) + z) / 4
        let g2 = (5 * pow(z, 5) + 16 * pow(z, 3) + 3 * z) / 96
        let g3 = (3 * pow(z, 7) + 19 * pow(z, 5) + 17 * pow(z, 3) - 15 * z) / 384
        let g4 = (79 * pow(z, 9) + 776 * pow(z, 7) + 1482 * pow(z, 5)
                  - 1920 * pow(z, 3) - 945 * z) / 92160
        return z + g1 / df1 + g2 / pow(df1, 2) + g3 / pow(df1, 3) + g4 / pow(df1, 4)
    }
}

// MARK: - Deterministic RNG (SplitMix64) + Gaussian sampling

public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Standard-normal sample via Box-Muller.
    public mutating func gaussian(mean: Double, sd: Double) -> Double {
        let u1 = max(Double.random(in: 0..<1, using: &self), 1e-12)
        let u2 = Double.random(in: 0..<1, using: &self)
        let mag = (-2 * Foundation.log(u1)).squareRoot()
        return mean + sd * mag * cos(2 * .pi * u2)
    }
}
