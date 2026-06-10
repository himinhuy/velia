# Phase 4 — Closed Beta (Weeks 12–16)

> Put it in front of real irregular-cycle Vietnamese users, tune the engine on their (locally held) data via opt-in feedback, and harden to launch quality. Beta cohort recruited from VN Facebook health groups (PCOS/TTC/perimenopause).
> References: `prd.md` §10, §11; `engineering-practices.md` §7.

---

## Objective

Validate accuracy, retention, and the discretion/trust story with ~30–100 real users; fix what breaks; reach launch-ready quality. Because data is local-first, "tuning on real data" means **opt-in, user-initiated feedback/exports**, never silent collection.

---

## Deliverable milestones

| # | Milestone | Output |
|---|---|---|
| 4.1 | TestFlight distribution | Beta build + onboarding instructions in Vietnamese |
| 4.2 | Cohort recruited | 30–100 target-segment users from FB groups; consent for opt-in feedback |
| 4.3 | Opt-in feedback channel | In-app "share my anonymized cycle stats" (explicit, user-initiated) + a feedback form; **no silent telemetry** |
| 4.4 | Real-world accuracy review | Compare predicted vs. actual for consenting users; check calibration holds in the wild |
| 4.5 | Stability hardening | Crash-free-session target; fix top crashes/bugs (MetricKit, opt-in reports) |
| 4.6 | Retention readout | Week-1 / week-4 retention; does the narrowing-range mechanic land? |
| 4.7 | Launch decision | `phase-4-results.md`: ship / iterate / pivot, with the numbers |

---

## Testable — with instructions

- All prior automated gates remain green on every build: `make verify-all`.
- New regression tests written for every beta-reported bug before it's fixed.
- Real-world calibration check (offline, on consenting users' shared stats): does the stated interval still cover at ~target rate?
- Crash triage via MetricKit + opt-in diagnostics (on-device, user-shared only).

```bash
make verify-all                      # must stay green for every beta build
make bench                           # engine regression — unchanged or improved
# real-world calibration: feed consented, anonymized exports through velia-bench-style eval
```

---

## Checkpoint ("G4 — Launch-ready")

- [ ] Crash-free sessions ≥ target (e.g., ≥ 99.5%).
- [ ] In-the-wild calibration holds within tolerance (the headline claim survives contact with real users).
- [ ] No P0/P1 bugs open; every fixed bug has a regression test.
- [ ] Discretion/app-lock works across the cohort's real devices; no PHI-leak reports.
- [ ] Retention signal is acceptable for a learning launch (interpret honestly — this is a traction market).
- [ ] All feedback collection was **opt-in and user-initiated**; zero silent telemetry (privacy invariant intact).
- [ ] `make verify-all` green; manual smoke on multiple physical devices passes.

---

## Validation steps

1. Ship build to TestFlight; verify clean-device first-run for several beta users.
2. Run a 2–4 week beta; collect opt-in stats + structured feedback.
3. Weekly: triage crashes/bugs, write regression tests, re-run `make verify-all`.
4. Mid-beta: real-world calibration check — does the 80% interval still cover ~80%?
5. End: compile `phase-4-results.md` (accuracy-in-wild, retention, stability, qualitative trust feedback).
6. Make the **launch / iterate / pivot** call against the data.

---

## Exit criteria → Public VN iOS launch

G4 met, launch decision = ship. Then: ramp content/growth, begin the next axes per `prd.md` §2 (Android for VN scale; US for revenue, gated behind the security audit + open-sourced crypto + E2E sync).
