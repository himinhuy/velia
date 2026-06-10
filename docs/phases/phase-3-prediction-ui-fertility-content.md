# Phase 3 — Prediction UI, Fertility, Content & Polish (Weeks 8–12)

> Surface the moat. Turn the validated engine into the warm, honest prediction experience, ship the manual + HealthKit fertility signals, layer in native Vietnamese education content, and polish to beta quality.
> References: `prd.md` §4.5, §5.1, §8; `architecture.md` §5, §8; `engineering-practices.md` §3.

---

## Objective

A user sees a calibrated next-period prediction with a visible confidence range that narrows as they log, an honest fertility/ovulation view, a clear "too irregular to predict" state, cycle-phase education in Vietnamese, and HealthKit-sourced temperature feeding fertility.

---

## Deliverable milestones

| # | Milestone | Output |
|---|---|---|
| 3.1 | Prediction home | Next-period range + confidence level, recomputed on each new log; cache via `prediction_cache` |
| 3.2 | Confidence-range UX | Visible range that **narrows as data accrues** — the retention mechanic; honest, not false-precise |
| 3.3 | "Too irregular" state | Dedicated honest UI when the engine's honesty gate fires |
| 3.4 | Cycle-phase view | Menstrual/follicular/ovulatory/luteal with plain-language Vietnamese explanations |
| 3.5 | Fertility view | Ovulation as a wider interval; integrates manual BBT/mucus/LH |
| 3.6 | HealthKit integration | Read wrist temp / HR / sleep (permission flow), tag source, feed engine |
| 3.7 | Education content | Native Vietnamese cycle/PCOS/perimenopause content, informational-not-diagnostic, cited |
| 3.8 | Polish | Empty states, haptics, animations, error handling, accessibility, app-store assets |

---

## Testable — with instructions

**Unit tests** (`make test`):
- Prediction view model maps `Prediction` → UI state correctly for all `mode`/`confidence` combinations.
- Confidence range narrows monotonically as more normal cycles are added (drives the mechanic).
- HealthKit mapper converts samples → `fertility_entries` with correct source tag (mocked HK store).
- Content manifest: every educational claim has a citation; lint for banned Tier-2/3 phrasing.

**Snapshot tests** (`make test-snapshot`):
- Prediction home in high/moderate/low confidence + "too irregular" state, light/dark, Dynamic Type.
- Cycle-phase + fertility views.

**UI tests** (`make test-ui`):
- Log cycles → prediction appears and range visibly tightens.
- "Too irregular" path renders the honest state (no fake number).
- HealthKit permission denied → graceful fallback to manual.

**Manual:**
```bash
make verify-all      # full gate; bench must still pass (engine unchanged in app integration)
```

---

## Checkpoint ("G3 — Beta-ready")

- [ ] Prediction matches engine output exactly (UI never fabricates or rounds away the interval).
- [ ] Confidence range **narrows as the user logs** — verified across several simulated cycles.
- [ ] "Too irregular to predict" renders honestly; no false precision anywhere.
- [ ] Ovulation shown as an explicitly wider/low-confidence estimate for irregular users.
- [ ] HealthKit permission flow works; denial degrades gracefully to manual.
- [ ] All education copy is native Vietnamese, informational-not-diagnostic, with citations; Tier-2/3 lint passes.
- [ ] `make verify-all` green on simulator **and** manual smoke passes on a physical device.
- [ ] Accessibility + Dynamic Type + dark mode pass on all primary screens.

---

## Validation steps

1. `make verify-all` → all gates green.
2. Simulate a multi-cycle history (script or manual) → confirm the range tightens and confidence rises honestly.
3. Force an irregular history → confirm honest "too irregular" state, no fabricated date.
4. Grant then deny HealthKit → confirm both paths behave correctly; temp data influences fertility when granted.
5. Review every educational screen for: Vietnamese fluency, non-diagnostic framing, citation present.
6. Full manual smoke on a physical device (lock, log, predict, export, delete, airplane mode).
7. Build the TestFlight archive → install on a clean device → first-run experience is correct.

---

## Exit criteria → Phase 4

A polished, honest, encrypted, Vietnamese iOS app that passes the full gate on device and is ready for real users. Proceed to closed beta.
