# Velia — Benchmark Data & Segment Priors (sourcing plan)

> Closes Phase 0 milestones **0.2** (real benchmark dataset) and **0.3** (cited segment priors).
> Two *separate* needs, often confused:
> - **Validation dataset** = real per-person sequences of period dates → run `velia-bench` for accuracy/calibration.
> - **Segment priors** = population parameters (mean/SD of cycle length per segment) → seed cold-start in `SegmentPriors.swift`.

---

## 1. Segment priors — DONE (literature-grounded, cited)

Encoded in `VeliaCore/Sources/VeliaCore/SegmentPriors.swift` with inline citations.

| Segment | Prior mean (days) | Prior SD | Source |
|---|---|---|---|
| typical | 29 | 4 | Bull 2019 (29.3 ± 5.2; 65% of cycles 25–30 d) |
| pcos | 35 | 12 | Apple WHS 2025 (mean 33.4–35.7 by age; within-person SD 8.4–11.0) |
| perimenopause | 32 | 14 | STRAW+10 (Harlow 2012) / SWAN (≥7-day variability, ≥60-day amenorrhea) |
| postpartum | 35 | 14 | Postpartum return-of-menses literature (highly variable, long early cycles) |
| unknown | 30 | 8 | Blend toward population w/ extra uncertainty |

**Citations**
1. Bull JR, Rowland SP, Scherwitzl EB, Scherwitzl R, Danielsson KG, Harper J. *Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles.* npj Digital Medicine 2:83 (2019). doi:10.1038/s41746-019-0152-7 — https://www.nature.com/articles/s41746-019-0152-7
2. Gibson EA, et al. *Menstrual cycle length variation by demographic characteristics from the Apple Women's Health Study.* npj Digital Medicine (2023). https://www.nature.com/articles/s41746-023-00848-1
3. Apple Women's Health Study. *Variability of menstrual cycles by age, PCOS, and early-life cycle irregularity.* AJOG (2025). https://pmc.ncbi.nlm.nih.gov/articles/PMC12915291/
4. Harlow SD, et al. *Executive summary of the STRAW+10 Workshop.* (2012).
5. SWAN — Study of Women's Health Across the Nation.

> These are *priors*, not the validation set. Re-fit them if a segment-labeled real dataset becomes available.

---

## 2. Validation dataset — acquisition plan

Ranked by how fast you can actually use them.

### Tier A — download now (open, citeable)
- **Fehring "Menstrual Cycle Data" (FedCycle), Marquette ePublications.**
  Real NFP-study cycles, downloadable CSV (`FedCycleData071012.csv`, ~290 kB).
  https://epublications.marquette.edu/data_nfp/7/
  *Pros:* open, immediate, real period/cycle data. *Cons:* small; population is fertility-aware women (few clinical PCOS/peri labels) → use the variance-based irregularity classifier (§4).

### Tier B — request access (large, research-grade)
- **Kindara dataset (Symul et al.).** De-identified self-tracked logs; the npj Digital Medicine 2019 paper is **CC-BY 4.0**, data via the authors/repo. Millions of cycles.
  https://www.nature.com/articles/s41746-019-0139-4
- **Natural Cycles (Bull 2019).** 600k+ cycles incl. BBT/LH. **Proprietary** — "available from Natural Cycles Nordic AB upon reasonable request." Best for accuracy + fertility (temp) validation.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/
- **Apple Women's Health Study.** 160k+ cycles **with PCOS labels** (the only labeled-segment source). Aggregated data on request via Harvard Chan; individual-level gated.
  https://hsph.harvard.edu/research/apple-womens-health-study/publications/

### Tier C — convenience (caveat-heavy)
- **Kaggle "menstrual cycle" datasets** — quick to grab but several are *synthetic* or tiny; verify provenance before trusting any accuracy number.
  https://www.kaggle.com/datasets/nikitabisht/menstrual-cycle-data

**Recommendation:** validate the engine on **FedCycle (Tier A) now**, in parallel request **Apple WHS (Tier B)** for the only PCOS-labeled real cycles. Treat Natural Cycles as the V2 fertility/temperature validation source.

### Reality check (2026-06): no public PCOS-rich individual data
We attempted Tier B and confirmed the barrier: Apple WHS / Natural Cycles / raw Kindara are all
access-gated, and the Kindara/Symul "public repo" only exposes **aggregated figures**, not per-user
sequences. So **don't block the build on a PCOS dataset.** The irregular-cycle wedge is validated via
the two-stage strategy in `docs/phases/phase-0-results.md`: **(1)** literature-calibrated synthetic now
(asserted by `testSyntheticMatchesPublishedDistributions`), **(2)** real consented PCOS/peri users in
closed beta (Phase 4). FedCycle confirms the engine on **real regular cycles** (medAE 1.5 d, 82.8%
calibration, n=1223) — re-create it any time with `scripts/convert_fedcycle.py`.

---

## 3. Converting a source to Velia's CSV

Target format (one row per period start): `user_id,segment,period_start (yyyy-MM-dd)`.

- **Source has period start dates** → map directly: each woman = a `user_id`, one row per start.
- **Source has cycle lengths only** (common; FedCycle stores lengths) → synthesize dates: pick any start (e.g. `2020-01-01`), then `next_start = prev_start + length`. Day-gaps are all the engine uses, so the anchor date is arbitrary.
- **No segment label** → set `segment = unknown` and rely on the variance-based classifier (§4) for the irregular subset.

A converter is a ~30-line script per source schema. (Offer: paste a few real rows and I'll write the exact converter + run it through `velia-bench --csv`.)

---

## 4. The labeling gap (and the fix)

Open datasets rarely carry clinical PCOS/peri/postpartum labels, but the gate's "irregular subset" currently keys off the `segment` column. Two options:
1. **Use Apple WHS** (the one labeled source) — gold standard, but gated.
2. **Add `--irregular-from-data`** to `velia-bench`: classify a user as irregular by *observed* cycle-length SD (e.g. within-person SD ≥ 7 days, matching the STRAW+10 threshold) instead of a label. More honest for unlabeled real data, and arguably the metric you actually care about.

**Recommendation:** implement option 2 so any Tier-A/B/C dataset can be evaluated on its irregular subset without manual labels.

---

## 5. Definition of a true Phase-0 GO
Provisional GO currently rests on synthetic data. It becomes a **real** GO when:
1. A real dataset (≥ FedCycle, ideally Apple WHS for PCOS) is converted to CSV and run via `velia-bench --csv`.
2. The Bayesian model beats naive-28 and simple-average on the **real** irregular subset, with interval calibration within tolerance.
3. Priors above are re-checked (and re-fit if a labeled set allows).
