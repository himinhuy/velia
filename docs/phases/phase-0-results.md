# Phase 0 — Results & Gate Decision

> Output of milestone 0.7. Generated from `VeliaCore` via `swift run velia-bench` and `swift test`.
> **Status: provisional GO** — passed on a *synthetic* stand-in dataset. Must be re-confirmed on the real licensed/public irregular-cycle dataset before it counts as a true gate pass (see Caveats).

---

## Benchmark results (seed 42, 240 synthetic users, 16 cycles each)

### All users
| Predictor | n | median AE (days) | mean AE | interval coverage (target 80%) |
|---|---|---|---|---|
| Naive28 | 3120 | 5.00 | 8.62 | 34.9% |
| SimpleAvg | 3120 | 4.67 | 7.19 | 68.6% |
| **Bayesian** | 3120 | **3.83** | **6.50** | **77.9%** |

### Irregular subset (PCOS / perimenopause / postpartum)
| Predictor | n | median AE (days) | mean AE | interval coverage (target 80%) |
|---|---|---|---|---|
| Naive28 | 2340 | 8.00 | 11.10 | 16.5% |
| SimpleAvg | 2340 | 7.33 | 9.14 | 66.6% |
| **Bayesian** | 2340 | **5.68** | **8.22** | **75.6%** |

---

## Gate evaluation

| Criterion | Result |
|---|---|
| Bayesian beats Naive28 on irregular median AE | ✅ 5.68 < 8.00 |
| Bayesian beats SimpleAvg on irregular median AE | ✅ 5.68 < 7.33 |
| Interval calibration within ±8pp of target (80%) | ✅ 75.6% vs 80% |
| Stable across seeds (1, 2, 3, 99) | ✅ (test `testGateStableAcrossSeeds`) |
| All engine unit/property tests green | ✅ 12/12 |

### Decision: **GO ✅** (provisional)

The recency-weighted, skip-aware Bayesian model materially outperforms both baselines on exactly the irregular cycles that are the product's wedge, and its confidence ranges are reasonably calibrated (the headline claim). Notably, the baselines are badly *over-confident* on irregular cycles (Naive28 covers only 16.5%) — the Bayesian model's honest, variance-aware intervals are the real differentiator.

---

## What works (and why it beats the baselines)

- **Skip/anovulatory down-weighting** keeps doubled cycles from poisoning the mean — the main lift on PCOS.
- **Recency weighting** tracks non-stationary trends (perimenopause lengthening, postpartum recovery) that a simple average lags.
- **Predictive variance + Student-t intervals** produce calibrated ranges instead of the baselines' overconfidence.
- **Honesty gate** switches to "too irregular to predict" rather than emitting a false-precise date.

---

## Real-data run — FedCycle (Fehring/Marquette), 2026-06-06

First validation on **real cycles** (not synthetic). Converted via `scripts/convert_fedcycle.py`
(129 clients with ≥4 cycles → 1,739 period starts), irregular subset derived from observed
variability (within-person SD ≥ 7d, STRAW+10).

Command:
```bash
python3 scripts/convert_fedcycle.py "FedCycleData071012 (2).csv" fedcycle.csv
swift run velia-bench --csv fedcycle.csv --irregular-from-data
```

| Subset | n | Bayesian medAE | meanAE | calibration (→80%) | gate |
|---|---|---|---|---|---|
| All users | 1223 | **1.48 d** | 2.13 | **82.8%** | — |
| Irregular | 18 | 5.01 d | 7.14 | 77.8% | PASS vs Naive28 (6.50) & SimpleAvg (5.62) |

**Decision: GO ✅ — but see the critical caveat.**

### Interpretation (honest)
- On **regular cycles** the engine is strong on real data: 1.5-day median error, well-calibrated
  (slightly conservative) intervals, large n. This is a legitimate real-world result.
- The **irregular subset is tiny (3 users / 18 evals).** FedCycle is a natural-family-planning
  cohort — almost entirely regular cyclers — so it **cannot meaningfully validate the irregular-cycle
  wedge**, which is the entire product thesis. The PASS on n=18 is not robust evidence.

### Validation strategy for the irregular wedge (no public PCOS data available)
Individual-level, PCOS-rich cycle data is **not freely obtainable** — Apple WHS, Natural Cycles, and
the raw Kindara set are all access-gated, and Kindara only publishes aggregated figures. So the
irregular-cycle claim is validated in two honest stages instead:

1. **Now — literature-calibrated synthetic.** The synthetic generator is tuned to reproduce published
   distributions (PCOS within-person SD 8–11 d per Apple WHS; regular mean ≈29 d per Bull 2019) and
   this is **asserted by a test** (`testSyntheticMatchesPublishedDistributions`). Measured values:
   typical mean 28.7 d / within-SD 2.2; PCOS mean 36.1 d / within-SD 10.7; perimenopause within-SD 11.5.
   → Claim allowed: *"validated on real regular cycles + synthetic irregular cycles calibrated to
   published clinical distributions."*
2. **Phase 4 — real consented users.** Recruit PCOS/perimenopause users from VN Facebook groups who
   opt in to share cycle history (on-device, consented). Re-run the gate on their real cycles. This is
   the definitive proof and the only path to *"validated on real irregular cycles."*

Do **not** market unqualified irregular-cycle superiority until stage 2 passes.

---

## Caveats (do not treat as a final pass)

1. **Synthetic data.** `SyntheticDataset` is a stand-in. The numbers prove the *machinery and the relative advantage*, not real-world accuracy. **Re-run on the real dataset (milestone 0.2) before locking the GO.**
2. **Coverage slightly under target** (75.6% vs 80%) on the irregular subset — expected, since genuine skip cycles are tail events. Acceptable within tolerance; revisit interval widening once real data is in.
3. **Segment priors are placeholders** (`SegmentPriors.swift`) — replace with cited clinical distributions (milestone 0.3).

## How to reproduce

```bash
cd VeliaCore
swift run velia-bench               # prints the tables above + GATE + GO/NO-GO (exit 0 = GO)
swift run velia-bench 99            # different seed
swift run velia-bench --csv <path>  # run against the REAL dataset (CSV: user_id,segment,period_start)
swift test                          # engine + gate + dataset-loader tests
```

To convert the provisional GO into a real one: export the licensed/public dataset to the CSV format
above (or implement `CycleDataset`), run `swift run velia-bench --csv <path>`, and confirm the gate
still passes on real cycles.

---

## Next (Phase 1)
The `CyclePredictor` protocol is stable; the app can depend on it. Carry forward: replace synthetic data with the real dataset, swap placeholder priors for cited ones, and keep `velia-bench` as a permanent CI job that re-runs on any engine change.
