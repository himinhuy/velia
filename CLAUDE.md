# Velia — repo guide

Privacy-first, accuracy-led menstrual health tracker. **iOS-only, native Swift/SwiftUI, local-first, on-device prediction.** Launching Vietnam-first (premium urban iPhone users). See `docs/` for the full picture.

## Read first
- `docs/prd.md` — product spec (v0.2, Vietnam-first / iOS-first / accuracy-led).
- `docs/discussion.md` — the decision log (the *why* behind every major choice; overrides recorded).
- `docs/architecture.md` — technical decisions, module graph, schema, encryption, engine spec. **§0 lists invariants that must never break.**
- `docs/engineering-practices.md` — coding standards, the test pyramid, privacy invariant tests, CI, `make` targets.
- `docs/phases/` — phased delivery plans (deliverables / testable instructions / checkpoints / validation). Phase 0 is the engine gate.

## Layout
- `VeliaCore/` — **pure-Swift domain + prediction engine** (no UIKit/GRDB/network). Builds & tests with plain SwiftPM today. This is the moat.
- `Project.swift`, `Tuist.swift` — Tuist project-as-code for the iOS app (run `tuist install && tuist generate`).
- `App/`, `Modules/Velia*` — app + feature/framework modules (stubs until their phase; dependency rules in architecture.md §2).
- `.github/workflows/ci.yml` — CI: engine gate + lint (+ app build once `Project.swift` is generatable).

## Commands
```bash
make bench          # Phase 0 engine gate — prints metrics + GO/NO-GO (exit 0 = GO)
make test           # VeliaCore unit + property + gate tests
make verify         # lint + tests (the standard gate)
make verify-all     # verify + bench + UI smoke
make bootstrap      # tuist install && tuist generate (needs Tuist)
make help           # list targets
```
Engine targets work now. App/UI targets activate after `make bootstrap` (Tuist not yet installed in all envs).

## Non-negotiable invariants (architecture.md §0 — enforce in tests/CI)
1. No health data leaves the device (zero PHI network calls at MVP).
2. No third-party analytics/ad/data-broker SDKs.
3. All PHI encrypted at rest (SQLCipher); DB key only in Secure-Enclave-gated Keychain.
4. Prediction is on-device only.
5. Every persisted row is sync-ready (UUID, updated_at, device_id, deleted_at).
6. No Tier-2/3 (contraception/diagnosis) claims in copy.

## Current status
Phase 0 engine: **GO**. Validated on **real regular cycles** (FedCycle: medAE 1.5d, 82.8% calibration, n=1223) + **literature-calibrated synthetic** irregular cycles (priors cited from Bull 2019 / Apple WHS; asserted by tests). Segment priors are sourced & cited (`SegmentPriors.swift`, `docs/data-sources.md`).
**Open:** no public PCOS-rich individual dataset exists (all access-gated) → the irregular-cycle claim is validated on synthetic now and must be confirmed on **real consented PCOS/peri users in Phase 4 beta** before being marketed unqualified. Next: Phase 1 (encrypted core). Recreate the real-data run with `scripts/convert_fedcycle.py` + `velia-bench --csv … --irregular-from-data`.
