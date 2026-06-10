import Foundation

/// Cold-start population priors per segment: prior mean cycle length (days) and a prior SD
/// expressing uncertainty in that mean / between-person spread. Used to seed the Bayesian
/// posterior before the user has logged enough cycles (docs/prd.md §4.4).
///
/// Values are grounded in published clinical/real-world datasets — see `References` below.
/// These are *priors* (population parameters), distinct from each user's own within-cycle
/// variability, which the engine estimates from their data (the likelihood variance).
public struct SegmentPrior: Sendable {
    public let mean: Double
    public let sd: Double

    /// Cycles longer than this (relative to user median) are treated as likely anovulatory/skipped.
    public func skipThreshold(userMedian: Double) -> Double {
        max(mean * 1.6, userMedian * 1.6, 45)
    }

    public static func base(for segment: Segment) -> SegmentPrior {
        switch segment {
        // Bull et al. 2019 (npj Digit Med): 612,613 ovulatory cycles, mean 29.3 ± 5.2 days;
        // 65% of cycles 25–30 days; only 13% exactly 28. Apple WHS 2023/2025: within-person SD
        // ~6 days for regular cyclers. Prior mean ≈ population mean; SD ≈ between-person spread.
        case .typical:        return SegmentPrior(mean: 29, sd: 4)

        // Apple Women's Health Study 2025 (AJOG): PCOS mean cycle length 33.4–35.7 days (by age),
        // within-individual SD 8.4–11.0 days (vs ~6 for regular). High mean + heavy variability.
        case .pcos:           return SegmentPrior(mean: 35, sd: 12)

        // STRAW+10 (Harlow et al. 2012) / SWAN: the menopausal transition begins with persistent
        // ≥7-day changes in consecutive cycle length and episodes of ≥60-day amenorrhea — i.e.
        // lengthening + sharply rising variability. Wide prior.
        case .perimenopause:  return SegmentPrior(mean: 32, sd: 14)

        // Postpartum return of menses is highly variable (≈6–8 wk if not breastfeeding; months while
        // lactating), and the first cycles are often long/irregular before normalizing. Wide prior.
        case .postpartum:     return SegmentPrior(mean: 35, sd: 14)

        // Unlabeled users: blend toward the population with extra uncertainty.
        case .unknown:        return SegmentPrior(mean: 30, sd: 8)
        }
    }

    /// Prior refined by the user's stated typical cycle length, if any.
    public static func forProfile(_ profile: UserProfile) -> SegmentPrior {
        let b = base(for: profile.segment)
        guard let typical = profile.typicalCycleLength, typical > 0 else { return b }
        // Trust the user's stated length for the mean; keep the segment's variability.
        return SegmentPrior(mean: Double(typical), sd: b.sd)
    }
}

// MARK: - References (sources for the priors above)
//
// 1. Bull JR, et al. "Real-world menstrual cycle characteristics of more than 600,000 menstrual
//    cycles." npj Digital Medicine 2:83 (2019). https://www.nature.com/articles/s41746-019-0152-7
//    Mean cycle length 29.3 ± 5.2 d; 65% of cycles 25–30 d; 13% exactly 28 d. (Natural Cycles)
// 2. Gibson EA, et al. "Menstrual cycle length variation by demographic characteristics from the
//    Apple Women's Health Study." npj Digital Medicine (2023).
//    https://www.nature.com/articles/s41746-023-00848-1
// 3. Apple Women's Health Study (Harvard Chan). "Variability of menstrual cycles by age, PCOS, and
//    early-life cycle irregularity." AJOG (2025). PMC12915291. PCOS within-individual SD 8.4–11.0 d.
// 4. Harlow SD, et al. "Executive summary of the STRAW+10 Workshop." (2012) — staging of
//    reproductive aging; perimenopause = persistent ≥7-day cycle-length variability + ≥60-day amenorrhea.
// 5. SWAN (Study of Women's Health Across the Nation) — cycle-length change across the transition.
//
// NOTE: these priors are literature-grounded but should be re-fit once a real, segment-labeled
// validation dataset is loaded (see docs/phases/phase-0-prediction-engine-gate.md, milestone 0.2/0.3).
