# VeliaCore

Pure-Swift domain models + the cycle-prediction engine (Phase 0). **No UIKit, no GRDB, no networking** — so it compiles and tests with plain SwiftPM and runs in the offline benchmark. This is the moat; everything in the app depends on the `CyclePredictor` protocol defined here.

See `docs/architecture.md` §5 and `docs/phases/phase-0-prediction-engine-gate.md`.

## Layout
- `Sources/VeliaCore/Models.swift` — `PeriodEvent`, `UserProfile`, `Prediction`, date helpers
- `Sources/VeliaCore/Stats.swift` — weighted stats, normal/Student-t quantiles, seeded RNG
- `Sources/VeliaCore/SegmentPriors.swift` — cold-start population priors (placeholders; replace with cited data)
- `Sources/VeliaCore/Predictors.swift` — `CyclePredictor` protocol, `Naive28`, `SimpleAverage`, `BayesianCyclePredictor`
- `Sources/VeliaCore/Benchmark.swift` — synthetic dataset + benchmark runner
- `Sources/velia-bench/` — Phase 0 gate CLI
- `Tests/VeliaCoreTests/` — golden cases, property invariants, and the gate test

## Commands
```bash
swift build
swift test                              # engine + gate + dataset-loader tests
swift run velia-bench                   # synthetic data — metrics + GO/NO-GO (exit 0 = GO)
swift run velia-bench 99                # alternate seed
swift run velia-bench --csv data.csv    # real dataset (see format below)
swift run velia-bench --export-csv out.csv [usersPerSegment]   # write a valid sample CSV
```

A ready-to-edit example lives at `docs/examples/sample-cycles.csv`.

## Swapping in the real dataset (Phase 0, milestone 0.2)
Dropping in real data is a one-file change: point `CSVCycleDataset` at the export, or implement the
`CycleDataset` protocol for another source. CSV format (header required), one row per period start:
```
user_id,segment,period_start
u001,pcos,2023-01-04
u001,pcos,2023-02-19
u002,typical,2023-01-02
```
`segment` ∈ {typical, pcos, perimenopause, postpartum, unknown}; `period_start` = `yyyy-MM-dd`.

## The engine in one paragraph
`BayesianCyclePredictor` derives cycle lengths from period starts, down-weights suspected
anovulatory/skipped cycles, recency-weights the rest, forms a Normal–Normal posterior over the
mean cycle length (seeded by a segment prior), and emits a **Student-t predictive interval** — which
*is* the visible confidence range. An honesty gate switches to `tooIrregularToPredict` rather than
showing a false-precise date. Ovulation is a separate, wider, lower-confidence estimate.
