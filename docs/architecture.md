# Velia — Technical Architecture & Decisions

> Detailed technical decisions for the Velia MVP. Derived from `docs/prd.md` (v0.2) and `docs/discussion.md`.
> Scope: **iOS-only, native Swift/SwiftUI, local-first, on-device prediction, sync-ready but sync-less, Tier-1 wellness.**
> Format: every decision states **what / why / alternatives rejected** so it can be revisited deliberately.

---

## 0. Architectural invariants (must never be violated)

These are testable contracts. Violating any of them is a release blocker (see `engineering-practices.md` → Privacy invariant tests).

1. **No health data leaves the device.** MVP makes **zero network calls** for PHI. (Enforced by an automated test that fails if any networking symbol is reachable from health code paths.)
2. **No third-party analytics / ad / data-broker SDKs.** Ever.
3. **All PHI is encrypted at rest** via SQLCipher; the DB key never exists in plaintext outside the Secure Enclave-gated Keychain item.
4. **Prediction runs on-device only.** No cloud inference.
5. **Every persisted row is sync-ready** (UUID id, `updated_at`, `device_id`, `deleted_at`) even though no sync code ships.
6. **No Tier-2/3 claims** in UI copy (no "prevents pregnancy", no diagnosis).

---

## 1. Platform & language decisions

| Decision | Choice | Why | Rejected alternatives |
|---|---|---|---|
| Platform | **iOS only** (launch) | Premium urban VN beachhead; cleanest crypto/HealthKit/CoreML surface | Cross-platform now (reuse benefit deferred; value is platform-specific) |
| Min iOS version | **iOS 17.0** | Target owns modern iPhones; Observation framework, mature SwiftUI, `.xcstrings`, Apple Watch wrist-temp (S8+) via HealthKit | iOS 15/16 (more legacy SwiftUI workarounds, no Observation) |
| Language | **Swift 6**, strict concurrency on | Compile-time data-race safety for an actor-isolated DB layer | Swift 5 mode (loses concurrency guarantees) |
| UI | **SwiftUI** | Fast, warm, declarative UI; matches "non-clinical warmth" goal | UIKit (slower to build the polish), React Native/Flutter (bridge tax for no current reuse) |
| Persistence | **GRDB.swift + SQLCipher** | Mature, fast, full SQL control, first-class encryption, easy migrations, testable | SwiftData (immature, weak encryption story, hard to bend to sync metadata), Realm (heavier, less SQL control), Core Data (verbose, awkward SQLCipher) |
| Crypto | **CryptoKit + Secure Enclave** | First-party, audited primitives; Enclave-backed keys | Third-party crypto libs (audit surface, trust cost) |
| Key storage | **Keychain item, Secure-Enclave-wrapped, biometric-gated** | Hardware-bound key, biometric unlock | Plain Keychain (no hardware binding), file-based key (insecure) |
| Health/sensors | **HealthKit** (read) | Single OS surface for Apple Watch wrist temp / HR / sleep | Per-device SDKs (US-tier later) |
| ML (V2) | **Core ML** (frozen model) | On-device inference, no cloud | TensorFlow Lite (extra dep; Core ML is native) |
| Dependencies | **Swift Package Manager** | Native, reproducible | CocoaPods/Carthage (legacy) |
| Project generation | **Tuist** (project-as-code) | Avoids `.xcodeproj` merge hell across modules; reproducible | Hand-managed `.xcodeproj` (merge conflicts), XcodeGen (less feature-rich for modular apps) |
| Observability | **OSLog + MetricKit** (on-device only) | Diagnostics without a third-party SDK or PHI leakage | Firebase/Sentry/etc. (violates invariant #2) |

**Dependency budget:** minimize third-party code (it's audit + trust surface). Approved at MVP: **GRDB (+SQLCipher), swift-collections** (if needed), **ViewInspector / swift-snapshot-testing** (test-only). New runtime deps require an explicit decision logged here.

---

## 2. Module / package structure

Local SPM packages, strict one-way dependency flow (enforced in CI — a feature importing the DB driver directly fails the build):

```
App (Velia)                      ← app target: composition root, navigation, DI wiring
└─ VeliaFeatures                 ← SwiftUI screens + view models (one folder per feature)
   ├─ VeliaDesignSystem          ← warm theming, reusable components, typography, color, haptics
   ├─ VeliaCore                  ← PURE Swift domain: models, the prediction engine, value types. NO UIKit, NO GRDB, NO Foundation-network.
   ├─ VeliaData                  ← GRDB + SQLCipher, repositories, migrations, mappers. Depends on VeliaCore + VeliaSecurity.
   ├─ VeliaSecurity              ← Keychain, Secure Enclave, app-lock engine, biometric/PIN.
   └─ VeliaHealth                ← HealthKit read wrappers, maps to VeliaCore types.
```

Dependency rule: `Features → (DesignSystem, Core, Data, Security, Health)`; `Data → (Core, Security)`; `Health → Core`; **`Core` depends on nothing.** The prediction engine living in dependency-free `VeliaCore` is what makes it trivially unit-testable and runnable in the offline benchmark harness.

---

## 3. Data model (sync-ready schema)

### 3.1 Common columns on every table
| Column | Type | Purpose |
|---|---|---|
| `id` | TEXT (UUID v4, client-generated) | Stable global PK; never autoincrement |
| `created_at` | INTEGER (epoch ms) | Audit |
| `updated_at` | INTEGER (epoch ms) | LWW conflict resolution |
| `device_id` | TEXT (UUID, per-install) | Sync provenance |
| `deleted_at` | INTEGER? (epoch ms, nullable) | **Soft delete tombstone — no hard deletes** |

### 3.2 Tables (MVP)
- **`user_profile`** — single row. Onboarding intake: `birth_year`, `typical_cycle_length`, `conditions` (JSON: pcos/perimenopause/postpartum/none), `last_periods` (seed dates), `segment` (derived prior key).
- **`period_events`** — `start_date`, `end_date?`, `flow_intensity?` (enum), `is_spotting` (bool).
- **`symptom_entries`** — `date`, `type` (enum: mood/energy/sleep/pain/etc.), `value` (scaled), `note?`. **One row per (date, type)** — fine-grained for clean LWW merges.
- **`fertility_entries`** — `date`, `bbt_celsius?`, `cervical_mucus?` (enum), `lh_test?` (enum: negative/peak), `source` (manual/healthkit).
- **`sex_entries`** — `date`, `protected` (bool/enum). Tier-1 framing only.
- **`notes`** — `date`, `text` (free, encrypted by DB).
- **`tags`** — user-defined `name`, `color`, `icon`.
- **`tag_values`** — `tag_id`, `date`, `value`.
- **`reminders`** — `type`, `schedule`, `enabled` (local notifications only).
- **`prediction_cache`** — derived; `computed_at`, `payload` (JSON of the latest `Prediction`). Recomputable; safe to drop.

### 3.3 Cycle derivation
A "cycle" is **not stored as a fat row** — it is *derived* from `period_events` by the engine, so anovulatory/skipped-cycle reinterpretation never requires a destructive migration. `prediction_cache` holds the derived view for fast reads.

### 3.4 Migrations
GRDB `DatabaseMigrator`, append-only, each migration named + tested. **Never edit a shipped migration.** A round-trip migration test runs on every CI build.

---

## 4. Encryption architecture

```
First launch:
  1. Generate 256-bit random DB key (CryptoKit SymmetricKey).
  2. Generate/obtain a Secure-Enclave private key (P-256, .privateKeyUsage, biometric access control).
  3. Wrap (encrypt) the DB key; store the wrapped blob in Keychain
     (kSecAttrAccessibleWhenUnlockedThisDeviceOnly, access control = .biometryCurrentSet / devicePasscode).
  4. Open SQLCipher DB with the unwrapped DB key.

Every app open:
  - App-lock gate (biometric/PIN) → unwrap DB key via Enclave → open DB. Key held only in memory while unlocked; zeroed on lock/background.
```

- **Export:** encrypted backup uses a **separate passphrase-derived key** (Argon2id/PBKDF or CryptoKit HKDF over a user passphrase) — independent of the device DB key so backups are portable.
- **Full delete:** drop the Keychain item + securely delete the DB file → data is cryptographically unrecoverable.
- **No plaintext PHI** ever written to disk, logs, or crash reports (OSLog uses `.private` redaction for any PHI-adjacent values).

---

## 5. Prediction engine architecture (the moat)

Lives entirely in **`VeliaCore`**, pure & deterministic (seedable RNG), so it runs in unit tests and the offline benchmark with no app.

### 5.1 Interface
```swift
protocol CyclePredictor {
    func predict(history: [PeriodEvent],
                 profile: UserProfile,
                 asOf: Date) -> Prediction
}

struct Prediction {
    let nextPeriod: DateInterval        // calibrated range, e.g. Mar 12–15
    let ovulation: DateInterval?        // wider interval; nil when too uncertain
    let cyclePhase: CyclePhase
    let confidence: ConfidenceLevel     // high / moderate / low
    let mode: PredictionMode            // .normal / .tooIrregularToPredict
    let intervalCoverageTarget: Double  // e.g. 0.8  (for calibration eval)
}
```

### 5.2 Pipeline
1. **Ingest & clean** raw `period_events` → cycle lengths.
2. **Anovulatory/skip detection** → flag/down-weight cycles beyond a segment-specific threshold (don't average a 60-day "cycle" raw).
3. **Recency weighting** (exponential) → recent cycles dominate (perimenopause/postpartum drift).
4. **Bayesian update** → per-user **posterior over cycle length** with a **heavy-tailed likelihood** (Student-t/log-normal), seeded by the intake + **segment population prior** (cold start, §PRD 4.4).
5. **Interval construction** → posterior credible interval = the visible confidence range.
6. **Ovulation** → estimated as its own quantity with a **wider** interval (+ manual BBT/mucus/LH and HealthKit temp when present).
7. **Honesty gate** → if interval width > threshold or regime change detected → `mode = .tooIrregularToPredict`.

### 5.3 Swappability (V2)
`CyclePredictor` is a protocol; the MVP `BayesianCyclePredictor` can be replaced by a `CoreMLCyclePredictor` in V2 with no change to callers.

### 5.4 Benchmark harness
A test-target + a small CLI (`velia-bench`) that loads the public irregular-cycle dataset, runs the predictor cycle-by-cycle, and reports **median absolute error** and **interval calibration/coverage** on the high-variance subset vs. **naive-28** and **simple-average** baselines. This *is* the Phase 0 gate (`docs/phases/phase-0-prediction-engine-gate.md`).

---

## 6. Discretion / app-lock architecture

- **Lock engine** (`VeliaSecurity`): `LAContext` biometric + PIN fallback; configurable auto-lock timeout; lock on `scenePhase == .background`.
- **App-switcher blur:** present an opaque cover view on `willResignActive`, remove on `didBecomeActive` (prevents snapshot leakage).
- **Neutral icon/name:** `setAlternateIconName` with abstract icons + a neutral display name option (**not** a deceptive clone — App Store Guideline 2.3).
- **Instant lock gesture:** a one-tap/long-press action → immediate lock/decoy screen.
- **Drop (not built):** fake-app disguise / panic-vanish (Apple-noncompliant; over-promise).

---

## 7. Navigation, state, concurrency

- **Navigation:** `NavigationStack` + a typed route enum per tab; tab bar root.
- **State:** SwiftUI `@Observable` view models (Observation framework). View models depend on **repository protocols** (from `VeliaData`), injected — never touch GRDB directly.
- **Concurrency:** DB access behind a GRDB `DatabasePool` accessed through an **actor**; `async/await` end-to-end; no shared mutable state across tasks.
- **DI:** simple constructor injection from the app composition root; a `Dependencies` container for previews/tests with in-memory fakes.

---

## 8. Localization & content

- **`.xcstrings` String Catalogs.** **Vietnamese is the base/default locale; English secondary.**
- All medical/educational copy is **native Vietnamese, informational-not-diagnostic**, with a disclaimer and per-claim source citation tracked in a content manifest.
- No hardcoded user-facing strings (lint rule).

---

## 9. Observability & quality (no third-party)

- **OSLog** with subsystem/category; PHI marked `.private`.
- **MetricKit** for on-device performance/crash diagnostics (stays on device unless the user explicitly shares).
- **No** Crashlytics/Sentry/Firebase/Amplitude. Optional aggregate, opt-in, on-device-only metrics are a *Later* item, post-audit.

---

## 10. Build, CI/CD, environments

- **Tuist** generates the project from `Project.swift`.
- **CI:** GitHub Actions (or Xcode Cloud) running lint → build → unit → snapshot → UI smoke → benchmark gate (see `engineering-practices.md`).
- **Single build config** at MVP (no staging server — there's no server). TestFlight for beta distribution.

---

## 11. Open technical questions (track to closure)

- Exact **segment prior distributions** (PCOS/perimenopause/postpartum) — sourced & validated before Phase 0 finishes.
- **PIN storage** scheme (hashed + Enclave-gated) details.
- **Backup format** spec & versioning.
- **Recovery UX** for E2E sync (deferred to US milestone, but design must not paint us into a corner).

---

*Phase-by-phase delivery plans: `docs/phases/`. Engineering standards, automated-testing strategy, and validation instructions: `docs/engineering-practices.md`.*
