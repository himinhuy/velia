# Phase 0 — Prediction Engine Gate (Weeks 0–4)

> **The go/no-go for the entire project.** Build the prediction engine in isolation and prove it beats naive baselines on irregular cycles with calibrated confidence ranges. **No app UI in this phase.** If the engine fails the gate, kill or pivot before building anything else.
> References: `architecture.md` §5, `engineering-practices.md` §3.1, `prd.md` §4.

---

## Objective

A pure-Swift, deterministic `BayesianCyclePredictor` in `VeliaCore`, plus an offline benchmark harness that measures it against a public irregular-cycle dataset and reports pass/fail vs. defined thresholds.

---

## Deliverable milestones

| # | Milestone | Output |
|---|---|---|
| 0.1 | Repo + tooling scaffold | Tuist project, `VeliaCore` package, SwiftLint/SwiftFormat, CI skeleton, `make` targets |
| 0.2 | Public benchmark dataset acquired & loaded | Dataset in a reproducible loader (no PHI committed; license noted), train/eval split, "high-variance subset" defined. **Sourcing plan + trusted sources: `docs/data-sources.md` §2.** |
| 0.3 | Segment population priors sourced & encoded | PCOS / perimenopause / postpartum / typical prior distributions in code, each with a cited source. **DONE (literature-grounded): `docs/data-sources.md` §1 + `SegmentPriors.swift`.** |
| 0.4 | Baselines implemented | `Naive28Predictor`, `SimpleAveragePredictor` conforming to `CyclePredictor` |
| 0.5 | `BayesianCyclePredictor` implemented | Full pipeline: clean → anovulatory detection → recency weighting → Bayesian posterior (heavy-tailed) → interval → ovulation → honesty gate |
| 0.6 | Benchmark harness + CLI | `velia-bench` runs cycle-by-cycle prediction, computes metrics, prints pass/fail table |
| 0.7 | Gate report | A committed `docs/phases/phase-0-results.md` with metrics, plots/tables, and the go/no-go decision |

---

## Testable — with instructions

**Unit / property tests** (`make test`):
- Golden cases: regular-28, PCOS-irregular, perimenopause-lengthening, postpartum-return, single-outlier, anovulatory-skip.
- Invariants (property tests over random histories): interval lower ≤ point ≤ upper; never crashes; `tooIrregularToPredict` engages above the variance gate; one normal new cycle doesn't swing output wildly (stability).
- Cold-start: with zero history + intake, engine returns a wide-but-valid interval (no crash, no false precision).

**Benchmark** (`make bench`):
```bash
make bench            # runs velia-bench on the eval split, prints:
                      #   median abs error (days)  — overall + high-variance subset
                      #   interval calibration/coverage @ target (e.g. 80%)
                      #   side-by-side vs Naive28 and SimpleAverage
                      #   PASS/FAIL vs gate thresholds
```

How to run from scratch:
```bash
make bootstrap
make test
make bench
```

---

## Checkpoint (must all be true to pass the gate / "G0")

- [ ] Engine is **pure** (no UIKit/GRDB/network), runs in plain unit tests + CLI.
- [ ] On the **high-variance (irregular) subset**, `BayesianCyclePredictor` beats **both** baselines on **median absolute error** by the agreed margin.
- [ ] **Interval calibration** is within tolerance of target (e.g., the 80% interval empirically covers ~76–84%). **Calibration is the headline claim — it must pass even if point-accuracy is only modestly better.**
- [ ] Honesty gate fires correctly on genuinely unpredictable histories (no overconfident output).
- [ ] All engine unit + property tests green; engine branch coverage effectively complete.
- [ ] `phase-0-results.md` committed with the explicit **GO / NO-GO** decision and the numbers behind it.

**Gate rule:** if calibration or the irregular-subset improvement fails, **stop**. Options: retune (more weeks here), re-scope the claim, or abandon. Do **not** proceed to Phase 1 on a failed gate.

---

## Validation steps

1. `make bootstrap && make test` → all engine tests green.
2. `make bench` → confirm the printed PASS for: irregular-subset MAE beats baselines, and calibration within tolerance.
3. Manually inspect 3–5 sample irregular histories: do the ranges *look* honest (wide when they should be, narrow when data is rich)?
4. Re-run `make bench` with a different random seed/split → results stable (not overfit to one split).
5. Peer/self-review `phase-0-results.md` against the gate rule; record GO/NO-GO.

---

## Exit criteria → Phase 1

GO decision recorded **and** the `CyclePredictor` protocol is stable enough that the app can depend on it. Carry forward: the segment priors, the dataset loader (for regression), and the benchmark as a permanent CI job (re-runs on any engine change).
