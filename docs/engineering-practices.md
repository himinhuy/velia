# Velia — Engineering Practices, Quality & Validation

> How we keep an irregular-cycle health app **correct, private, and warm** while a solo founder ships it. Automation does the watching so the human can build.
> Companion to `docs/architecture.md`. Every phase doc in `docs/phases/` references the "Validation steps" defined here.

---

## 1. Definition of Done (every feature/PR)

A change is **done** only when **all** of these are true:

- [ ] Code compiles with **zero warnings** (warnings-as-errors in CI).
- [ ] **SwiftLint** + **SwiftFormat** pass (no new violations).
- [ ] New logic has **unit tests**; bug fixes ship with a **regression test**.
- [ ] UI changes have/maintain **snapshot tests**; critical flows covered by **UI tests**.
- [ ] **Privacy invariant tests** pass (no network for PHI, no banned SDKs, PHI encrypted).
- [ ] **Accessibility**: Dynamic Type + VoiceOver labels on new interactive views.
- [ ] **Localization**: no hardcoded user-facing strings; keys added to `.xcstrings`.
- [ ] CI is green (lint → build → test → snapshot → UI smoke → benchmark gate where relevant).
- [ ] The phase doc's **Checkpoint** items for the touched area still hold.

---

## 2. Coding practices

### 2.1 Architecture rules (enforced, not aspirational)
- **One-way dependencies** (see `architecture.md` §2). A feature importing GRDB/SQLCipher directly = build failure. Validated by a CI check that greps module imports against an allow-list.
- **`VeliaCore` stays pure** — no UIKit/SwiftUI, no GRDB, no networking. The prediction engine must be runnable in a plain unit test and the CLI benchmark.
- **View models depend on protocols**, never concrete repositories or GRDB types. Enables in-memory fakes for tests/previews.
- **No singletons for stateful services.** Constructor injection from the composition root.

### 2.2 Style
- **SwiftFormat** for formatting (config in repo). **SwiftLint** for rules (incl. `file_length`, `type_body_length`, `force_unwrapping` warnings).
- **No force-unwraps** in non-test code except documented invariants. **No `try!`** on PHI paths.
- Naming: types `UpperCamelCase`, members `lowerCamelCase`, one primary type per file.
- Functions small and single-purpose; prefer value types (`struct`/`enum`) and immutability.

### 2.3 Concurrency
- `async/await` only; **no completion handlers** in new code.
- DB access goes through the `VeliaData` actor — never open the pool from a view model.
- Swift 6 strict concurrency on; resolve data-race diagnostics, never silence them.

### 2.4 Privacy-by-construction
- PHI never logged in plaintext (`OSLog` `.private`).
- No `URLSession`/network in `VeliaCore`, `VeliaData`, `VeliaHealth` at MVP.
- No third-party analytics/ad/crash SDK added without updating `architecture.md` §1 dependency budget *and* the invariant tests.

### 2.5 Git & review
- **Trunk-based**, short-lived branches: `feat/…`, `fix/…`, `chore/…`.
- Conventional-commit messages; PRs small and self-reviewed against the DoD checklist (solo founder: use the checklist as the reviewer).
- Never commit secrets/keys/datasets containing PHI. `.gitignore` covers `*.sqlite`, exports, dataset files.

---

## 3. Automated testing strategy (the pyramid)

| Layer | Tool | Covers | Target |
|---|---|---|---|
| **Unit** | Swift Testing / XCTest | Prediction engine, repositories, migrations, crypto, date math, view-model logic | **≥ 85%** line coverage on `VeliaCore` + `VeliaData`; engine effectively 100% of branches |
| **Property / fuzz** | Swift Testing parameterized | Engine never crashes / never returns invalid intervals across random histories | Key invariants hold for N random inputs |
| **Snapshot** | swift-snapshot-testing | Design-system components + key screens, light/dark, Dynamic Type sizes | All shared components + each primary screen |
| **UI / E2E** | XCUITest | Critical flows (see §3.3) on simulator | All "critical flows" green per build |
| **Privacy invariant** | XCTest | Architectural contracts (§4) | 100% pass — release blocker |
| **Benchmark gate** | CLI + XCTest | Engine accuracy/calibration vs. baselines | Phase 0 thresholds met |

### 3.1 Engine tests (highest priority — it's the moat)
- Deterministic with seeded RNG.
- Golden-case tests: regular 28-day, PCOS-irregular, perimenopause-lengthening, postpartum-return, single-outlier, anovulatory-skip.
- Invariants (property tests): interval lower ≤ predicted ≤ upper; ovulation interval ⊇ tighter than period only when justified; `tooIrregularToPredict` engages when variance exceeds gate; predictions are monotonic-stable (one new normal cycle doesn't wildly swing output).
- **Calibration test:** over the benchmark set, empirical coverage of the stated interval is within tolerance of the target (e.g., 80% interval covers ~76–84%).

### 3.2 Data/crypto tests
- Migration round-trip (apply all migrations on a fresh DB; assert schema; never edit shipped migrations).
- Soft-delete: deleted rows are tombstoned, excluded from reads, retained in store.
- Sync-readiness: every table has `id/created_at/updated_at/device_id/deleted_at` (a reflection test enforces this on all tables).
- Encryption: DB file on disk is **not** readable without the key (open-without-key must fail); full-delete renders data unrecoverable.

### 3.3 Critical UI flows (must always pass)
1. First-run onboarding intake → seeded prediction shown.
2. Log a period → calendar/timeline updates → prediction recomputes.
3. Log symptom / fertility (BBT/mucus/LH) entries.
4. App-lock: background → blur → relaunch → biometric/PIN gate.
5. Export encrypted backup; full delete wipes data.
6. "Too irregular to predict" state renders honestly.

---

## 4. Privacy invariant tests (release blockers)

Automated tests that fail the build if an invariant from `architecture.md` §0 breaks:

- **No-network-for-PHI:** assert `VeliaCore`/`VeliaData`/`VeliaHealth` link no networking; an integration test runs core flows behind a network sandbox that records 0 outbound requests.
- **No banned SDKs:** CI greps the resolved SPM dependency graph against a denylist (Firebase, Sentry, GoogleAnalytics, Facebook, Amplitude, ad SDKs).
- **Encrypted-at-rest:** test opens the on-disk DB without the key and asserts failure.
- **Sync-metadata present:** schema reflection asserts all tables carry the common columns.
- **No Tier-2/3 copy:** a string-catalog lint scans for banned phrases ("prevent pregnancy", "diagnose", "contraception" used as a claim) and fails if present.

---

## 5. CI/CD pipeline (runs on every PR + main)

```
1. Resolve deps            → fail on banned SDK (denylist check)
2. Lint                    → SwiftFormat --lint, SwiftLint (warnings = errors)
3. Module-boundary check   → import allow-list per package
4. Build                   → all schemes, warnings-as-errors
5. Unit + property tests   → coverage gate (≥85% Core/Data)
6. Privacy invariant tests → release blocker
7. Snapshot tests          → fail on visual diff
8. UI smoke (critical flows)→ simulator
9. Benchmark gate          → (Phase 0 + on engine changes) accuracy/calibration thresholds
10. Coverage report        → posted to PR
```

- **Pre-commit hook** (local, fast): SwiftFormat + SwiftLint + affected unit tests.
- **Pre-push hook:** full unit + privacy invariant tests.
- Nightly: full UI suite + benchmark on the full dataset.

---

## 6. How to run / validate locally (the "Validation steps" phases refer to)

> Commands assume Tuist + SPM. Adjust to the actual Makefile once scaffolded; the Makefile should expose these exact targets so phase docs stay stable.

```bash
make bootstrap        # tuist install && tuist generate
make lint             # SwiftFormat --lint + SwiftLint
make test             # all unit + property + privacy invariant tests
make test-snapshot    # snapshot tests
make test-ui          # XCUITest critical flows on a booted simulator
make bench            # run velia-bench against the benchmark dataset, print metrics + pass/fail vs gate
make verify           # lint + test + test-snapshot + privacy invariants  (the standard gate)
make verify-all       # verify + test-ui + bench  (full gate)
make deploy-device    # generate→build→install→launch on the connected iPhone (see §6.1)
```

**Manual smoke (per phase Checkpoint):**
1. Run on an **iPhone simulator** *and* one **physical device** (Secure Enclave/biometric only fully testable on device).
2. Walk the phase's critical flows by hand.
3. Confirm Vietnamese is the default language and no string shows a raw key.
4. Background the app → confirm switcher blur → relaunch → confirm lock gate.
5. Airplane mode → confirm full functionality (local-first).

### 6.1 Running on a physical device

One command does generate → build → install → launch on the connected iPhone:

```bash
make deploy-device
```

It auto-resolves Tuist (PATH or mise) and auto-detects the connected device's ID — no hardcoded device. It produces a **standalone** install: the native `.app` lives in device storage, so once installed you can unplug the Mac, lock, and tap the icon to launch. There is no dev server (this is native SwiftUI, not RN/Expo).

**Signing.** Automatic, development-only — Xcode provisions an *Apple Development* profile (`CODE_SIGN_STYLE=Automatic`, `DEVELOPMENT_TEAM` resolved in `Project.swift` via `Environment.developmentTeam`, default `42C434U7BU`). Never a distribution/App Store profile. Override the team with `TUIST_DEVELOPMENT_TEAM=XXXXXXXXXX make deploy-device`.

**If `make deploy-device` fails:**
- *"may need to be unlocked"* / destination timeout → unlock the phone and keep it awake, then rerun. USB is more reliable than Wi-Fi for the install tunnel.
- No device found → unlock + plug in, confirm with `xcrun devicectl list devices`.

**Free Apple ID caveats** (the default dev account today):
- **7-day expiry.** The development profile is valid ~7 days; after that the app won't launch until you rerun `make deploy-device`. (A paid Developer Program membership extends this to ~1 year.)
- **HealthKit is gated.** `com.apple.developer.healthkit` is **not available to free Apple IDs**. Today's builds sign fine only because HealthKit isn't wired in yet; once the `VeliaHealth` capability is enabled, **device** builds will fail signing on a free account — enroll in the paid program before shipping HealthKit to a real device. Simulator builds are unaffected.
- Limits: max 3 sideloaded apps per device, 10 new bundle IDs / 7 days.

---

## 7. Quality gates by phase

| Gate | When | Blocks |
|---|---|---|
| **G0 Engine gate** | End of Phase 0 | Whole project — kill/pivot if accuracy/calibration thresholds unmet |
| **G1 Secure core** | End of Phase 1 | Any feature work — encryption, app-lock, migrations must be solid |
| **G2 Tracking complete** | End of Phase 2 | Prediction UI — data capture must be correct & tested |
| **G3 Beta-ready** | End of Phase 3 | Beta — full `make verify-all` green + manual smoke on device |
| **G4 Launch-ready** | End of Phase 4 | Public launch — beta feedback triaged, crash-free sessions target met |

Each phase doc defines the concrete pass/fail criteria for its gate.

---

*Per-phase plans with deliverables, test instructions, checkpoints, and validation steps: `docs/phases/`.*
