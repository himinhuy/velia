import XCTest
@testable import VeliaCore

final class EngineTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_600_000_000)

    private func history(lengths: [Double]) -> [PeriodEvent] {
        var starts: [Date] = [epoch]
        for l in lengths {
            starts.append(DayMath.add(days: l, to: starts.last!))
        }
        return starts.map { PeriodEvent(startDate: $0) }
    }

    // MARK: Stats sanity

    func testNormalQuantileSymmetry() {
        XCTAssertEqual(Stats.normalQuantile(0.5), 0, accuracy: 1e-6)
        XCTAssertEqual(Stats.normalQuantile(0.975), 1.959964, accuracy: 1e-3)
        XCTAssertEqual(Stats.normalQuantile(0.90), 1.281552, accuracy: 1e-3)
    }

    func testTQuantileWiderThanNormal() {
        // Student-t has heavier tails → larger quantile than normal at small df.
        XCTAssertGreaterThan(Stats.tQuantile(0.975, df: 5), Stats.normalQuantile(0.975))
    }

    func testWeightedStats() {
        let w = Stats.weighted(values: [10, 20, 30], weights: [1, 1, 1])
        XCTAssertEqual(w.mean, 20, accuracy: 1e-9)
        XCTAssertEqual(w.effectiveN, 3, accuracy: 1e-9)
    }

    // MARK: Golden cases

    func testRegularCyclePredictsNearMean() throws {
        let h = history(lengths: Array(repeating: 28, count: 8))
        let p = BayesianCyclePredictor().predict(history: h, profile: .init(segment: .typical), asOf: epoch)
        let last = try XCTUnwrap(h.map(\.startDate).max())
        let predictedLen = DayMath.daysBetween(last, p.pointDate)
        XCTAssertEqual(predictedLen, 28, accuracy: 1.5)
        XCTAssertEqual(p.mode, .normal)
        XCTAssertEqual(p.confidence, .high)
    }

    func testPredictionIntervalContainsPoint() {
        let h = history(lengths: [27, 29, 28, 30, 26, 28])
        let p = BayesianCyclePredictor().predict(history: h, profile: .init(segment: .typical), asOf: epoch)
        XCTAssertLessThanOrEqual(p.nextPeriod.start, p.pointDate)
        XCTAssertGreaterThanOrEqual(p.nextPeriod.end, p.pointDate)
    }

    func testHighlyIrregularTriggersHonestyGate() {
        let h = history(lengths: [24, 70, 31, 90, 22, 65, 40])
        let p = BayesianCyclePredictor().predict(history: h, profile: .init(segment: .pcos), asOf: epoch)
        XCTAssertEqual(p.mode, .tooIrregularToPredict)
        // Still returns a (wide) range — never refuses to show anything.
        XCTAssertGreaterThan(DayMath.daysBetween(p.nextPeriod.start, p.nextPeriod.end), 10)
    }

    func testColdStartUsesPriorAndIsHonest() {
        let p = BayesianCyclePredictor().predict(history: [], profile: .init(segment: .pcos), asOf: epoch)
        // No history + high-variance segment ⇒ honest low-confidence, but still a usable window.
        XCTAssertEqual(p.mode, .tooIrregularToPredict)
        XCTAssertGreaterThan(DayMath.daysBetween(epoch, p.nextPeriod.start), 0)
    }

    func testSkipCycleDoesNotPoisonMean() throws {
        // One anovulatory double-cycle should not drag the prediction toward 56.
        let h = history(lengths: [28, 28, 56, 28, 28])
        let p = BayesianCyclePredictor().predict(history: h, profile: .init(segment: .typical), asOf: epoch)
        let last = try XCTUnwrap(h.map(\.startDate).max())
        let predictedLen = DayMath.daysBetween(last, p.pointDate)
        XCTAssertLessThan(predictedLen, 36, "skip cycle poisoned the estimate")
    }

    func testRecencyWeightingTracksLengtheningTrend() throws {
        // Cycles lengthening; prediction should lean toward recent (longer) values, not the overall mean.
        let h = history(lengths: [26, 28, 30, 33, 36, 39])
        let p = BayesianCyclePredictor().predict(history: h, profile: .init(segment: .perimenopause), asOf: epoch)
        let last = try XCTUnwrap(h.map(\.startDate).max())
        let predictedLen = DayMath.daysBetween(last, p.pointDate)
        let overallMean = Stats.mean([26, 28, 30, 33, 36, 39]) // ≈ 32
        XCTAssertGreaterThan(predictedLen, overallMean, "recency weighting not tracking the trend")
    }

    // MARK: Property — invariants over random histories

    func testNeverProducesInvalidInterval() throws {
        var rng = SeededRNG(seed: 7)
        let predictor = BayesianCyclePredictor()
        for _ in 0 ..< 500 {
            let n = Int.random(in: 0 ... 12, using: &rng)
            let lengths = (0 ..< n).map { _ in Double(Int.random(in: 18 ... 95, using: &rng)) }
            let seg = try XCTUnwrap(Segment.allCases.randomElement(using: &rng))
            let p = predictor.predict(
                history: history(lengths: lengths),
                profile: .init(segment: seg),
                asOf: epoch
            )
            XCTAssertLessThanOrEqual(p.nextPeriod.start, p.nextPeriod.end)
            XCTAssertFalse(p.pointDate.timeIntervalSince1970.isNaN)
            if let ov = p.ovulation { XCTAssertLessThanOrEqual(ov.start, ov.end) }
        }
    }

    // MARK: The gate (mirrors velia-bench thresholds)

    func testEngineGate_beatsBaselinesAndIsCalibrated() {
        let users = SyntheticDataset.generate(seed: 42)
        let bayes = Benchmark.evaluate(
            predictor: BayesianCyclePredictor(),
            name: "Bayesian",
            users: users,
            onlyIrregular: true
        )
        let naive = Benchmark.evaluate(
            predictor: Naive28Predictor(),
            name: "Naive28",
            users: users,
            onlyIrregular: true
        )
        let avg = Benchmark.evaluate(
            predictor: SimpleAveragePredictor(),
            name: "SimpleAvg",
            users: users,
            onlyIrregular: true
        )

        XCTAssertLessThan(bayes.medianAbsError, naive.medianAbsError, "must beat naive-28 on irregular cycles")
        XCTAssertLessThan(bayes.medianAbsError, avg.medianAbsError, "must beat simple-average on irregular cycles")
        XCTAssertEqual(bayes.coverage, bayes.coverageTarget, accuracy: 0.08, "interval must be calibrated")
    }

    // MARK: Dataset loader

    func testCSVDatasetParsesAndGroupsByUser() throws {
        let csv = """
        user_id,segment,period_start
        u001,pcos,2023-01-04
        u001,pcos,2023-03-19
        u001,pcos,2023-02-19
        u002,typical,2023-01-02
        u002,typical,2023-01-30

        """
        let users = try CSVCycleDataset.parse(csv)
        XCTAssertEqual(users.count, 2)
        let u1 = users[0]
        XCTAssertEqual(u1.segment, .pcos)
        XCTAssertTrue(u1.isIrregular)
        XCTAssertEqual(u1.history.count, 3)
        // Dates must be sorted ascending even when the file isn't.
        XCTAssertEqual(u1.history.map(\.startDate), u1.history.map(\.startDate).sorted())
        XCTAssertFalse(users[1].isIrregular)
    }

    func testCSVDatasetRejectsBadInput() {
        XCTAssertThrowsError(try CSVCycleDataset.parse("user_id,segment,period_start\nu1,pcos")) // missing column
        XCTAssertThrowsError(try CSVCycleDataset
            .parse("user_id,segment,period_start\nu1,martian,2023-01-01")) // bad segment
        XCTAssertThrowsError(try CSVCycleDataset.parse("user_id,segment,period_start\nu1,pcos,01/01/2023")) // bad date
    }

    func testCSVRoundTrip() throws {
        let original = SyntheticDataset.generate(seed: 3, usersPerSegment: 5, cyclesPerUser: 9)
        let csv = CSVCycleDataset.serialize(original)
        let reparsed = try CSVCycleDataset.parse(csv)
        XCTAssertEqual(reparsed.count, original.count)
        for (a, b) in zip(original, reparsed) {
            XCTAssertEqual(a.segment, b.segment)
            XCTAssertEqual(a.history.count, b.history.count)
            XCTAssertEqual(a.history.map(\.startDate), b.history.map(\.startDate))
        }
    }

    func testSyntheticDatasetConformsToProtocol() throws {
        let dataset: CycleDataset = SyntheticCycleDataset(seed: 5, usersPerSegment: 4, cyclesPerUser: 10)
        let users = try dataset.load()
        XCTAssertEqual(users.count, 16) // 4 segments × 4
    }

    func testSyntheticMatchesPublishedDistributions() {
        // The synthetic generator must reproduce literature distributions (docs/data-sources.md §1)
        // so the irregular cohort is a defensible stand-in until real PCOS data exists.
        let users = SyntheticDataset.generate(seed: 42)
        func stats(_ seg: Segment) -> (meanLen: Double, medWithinSD: Double) {
            let us = users.filter { $0.segment == seg }
            let lengths = us.flatMap { CycleDerivation.lengths(from: $0.history) }
            let withinSDs = us.map(\.cycleLengthSD).sorted()
            return (Stats.mean(lengths), withinSDs[withinSDs.count / 2])
        }

        let typical = stats(.typical)
        let pcos = stats(.pcos)
        let peri = stats(.perimenopause)
        print("SYNTHETIC: typical=\(typical) pcos=\(pcos) peri=\(peri)")

        // Bull 2019: regular mean ≈ 29; within-person variation small.
        XCTAssertEqual(typical.meanLen, 29, accuracy: 2.5)
        XCTAssertLessThan(typical.medWithinSD, 4)
        // Apple WHS 2025: PCOS mean ≈ 33–36, within-person SD ≈ 8–11.
        XCTAssertGreaterThan(pcos.meanLen, 31)
        XCTAssertTrue((7 ... 12).contains(pcos.medWithinSD), "PCOS within-person SD \(pcos.medWithinSD) outside 7–12")
        // STRAW+10: perimenopause variability elevated (≥7-day changes).
        XCTAssertGreaterThan(peri.medWithinSD, 6)
    }

    func testPredictionDemoProducesValidPrediction() {
        let asOf = Date(timeIntervalSince1970: 1_700_000_000)
        let p = PredictionDemo.sample(asOf: asOf)
        XCTAssertEqual(p.mode, .normal)
        XCTAssertLessThanOrEqual(p.nextPeriod.start, p.nextPeriod.end)
        XCTAssertFalse(PredictionDemo.sampleSummary(asOf: asOf).isEmpty)
        XCTAssertEqual(PredictionDemo.sampleHistory(asOf: asOf).count, 7) // 6 cycles → 7 starts
    }

    func testIrregularityClassifierFromData() {
        // Regular user: tight cycles → classified regular. Irregular user: high SD → irregular.
        let regular = BenchmarkUser(
            segment: .unknown,
            history: history(lengths: [28, 29, 27, 28, 30]),
            isIrregular: false
        )
        let irregular = BenchmarkUser(
            segment: .unknown,
            history: history(lengths: [24, 45, 30, 60, 28]),
            isIrregular: false
        )
        let out = IrregularityClassifier.apply([regular, irregular]) // default STRAW threshold = 7d
        XCTAssertFalse(out[0].isIrregular)
        XCTAssertTrue(out[1].isIrregular)
    }

    func testGateStableAcrossSeeds() {
        for seed: UInt64 in [1, 2, 3, 99] {
            let users = SyntheticDataset.generate(seed: seed)
            let bayes = Benchmark.evaluate(
                predictor: BayesianCyclePredictor(),
                name: "Bayesian",
                users: users,
                onlyIrregular: true
            )
            let avg = Benchmark.evaluate(
                predictor: SimpleAveragePredictor(),
                name: "SimpleAvg",
                users: users,
                onlyIrregular: true
            )
            XCTAssertLessThan(bayes.medianAbsError, avg.medianAbsError, "seed \(seed): not robust")
        }
    }
}
