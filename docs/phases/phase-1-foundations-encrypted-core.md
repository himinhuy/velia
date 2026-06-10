# Phase 1 — Foundations & Encrypted Core (Weeks 4–8, part 1)

> Build the secure, local-first skeleton everything else sits on: the encrypted database, the Secure-Enclave key handling, the sync-ready schema, and the app-lock/discretion suite. **Get this right before any tracking UI** — it's the trust foundation and the most expensive thing to retrofit.
> References: `architecture.md` §3, §4, §6, §7; `engineering-practices.md` §4.

---

## Objective

A runnable app shell that: opens an encrypted SQLCipher DB via an Enclave-gated key, enforces biometric/PIN app-lock with switcher blur, and exposes typed repositories over the sync-ready schema. No cycle features yet — just the secure substrate.

## Scaffolding status (current)
- ✅ **Sync-ready persistence model — built & tested** (pure Swift in `VeliaCore/Persistence.swift`): `SyncMetadata`, `SyncRecord`, the `Repository` protocol, `InMemoryRepository`, **LWW merge**, soft-delete/tombstone semantics, and `PeriodRecord/SymptomRecord/FertilityRecord`. 7 passing tests (`PersistenceTests`) cover upsert/fetch, soft-delete retention, LWW ordering, merge-doesn't-resurrect-deleted, Codable round-trip. *Refinement vs architecture §2: the storage contracts + reference in-memory impl live in pure `VeliaCore`; `VeliaData` provides the encrypted GRDB impl of the same protocol.*
- 🧱 **Encryption key path — scaffolded** (`VeliaSecurity/DatabaseKeyProvider.swift`): 256-bit key gen, Secure-Enclave ECIES wrap/unwrap, biometric-gated Keychain storage, cryptographic full-delete. *Requires Tuist/Xcode build to compile & verify on device.*
- 🧱 **App-lock — scaffolded** (`VeliaSecurity/BiometricAppLock.swift`): LAContext biometric + passcode fallback state machine.
- 🧱 **Encrypted DB + schema + GRDB repo — scaffolded** (`VeliaData/AppDatabase.swift`, `Repositories.swift`): SQLCipher `DatabasePool`, v1 migrator with sync columns on every table, `GRDBPeriodRepository` conforming to `VeliaCore.Repository` with row mapping.
- ✅ **Encrypted export/import codec — built & tested** (`VeliaCore/BackupCodec.swift`): AES-GCM seal/open with a portable envelope (version + salt + sealed box). 5 passing tests: round-trip, wrong-key-fails, tamper-fails, header-readable-without-key, salt entropy. *KDF-agnostic by design — production passphrase→key MUST use a slow KDF (PBKDF2/Argon2id) in the security layer; documented in-file.*
- ⏳ **Remaining for G1:** wire into the app, app-switcher blur (UIScene), neutral icon, passphrase KDF for export, and on-device verification of biometric/Enclave. Build requires `make bootstrap` (Tuist).

---

## Deliverable milestones

| # | Milestone | Output |
|---|---|---|
| 1.1 | App scaffold | iOS app target (iOS 17, Swift 6), tab shell, DI composition root, all SPM packages wired |
| 1.2 | Encrypted DB | GRDB + SQLCipher `DatabasePool` behind the `VeliaData` actor; DB opens with the key, fails without it |
| 1.3 | Key management | 256-bit DB key generated, Enclave-wrapped, stored in biometric-gated Keychain; in-memory only while unlocked |
| 1.4 | Schema + migrations | All MVP tables (`architecture.md` §3) with common sync columns; `DatabaseMigrator` v1; round-trip tested |
| 1.5 | Repository layer | Protocol-based repositories (CRUD + soft-delete) for each table; in-memory fakes for tests |
| 1.6 | App-lock engine | `VeliaSecurity`: biometric/PIN, auto-lock timeout, lock-on-background |
| 1.7 | Discretion suite | App-switcher blur, neutral icon/name option, instant lock gesture |
| 1.8 | Export / full-delete | Encrypted backup (passphrase-derived key) + cryptographic full-delete |

---

## Testable — with instructions

**Unit tests** (`make test`):
- Migration round-trip on a fresh DB; schema assertions.
- Soft-delete: tombstoned rows excluded from reads, retained in store.
- Sync-readiness reflection test: every table has `id/created_at/updated_at/device_id/deleted_at`.
- Repository CRUD against in-memory DB.

**Privacy invariant tests** (`make test`, release blockers):
- Open the on-disk DB file **without** the key → must fail.
- Full-delete → DB unrecoverable.
- No-network linkage check on `VeliaData`/`VeliaSecurity`.
- Banned-SDK denylist passes.

**UI tests** (`make test-ui`):
- Background app → switcher blur present → relaunch → app-lock gate appears → unlock succeeds.

**Manual (physical device required for Enclave/biometric):**
```bash
make verify          # lint + unit + snapshot + privacy invariants
make test-ui         # critical lock flow on simulator
# then run on a real iPhone for biometric + Enclave:
#  - set up Face ID/PIN, lock/unlock, change icon, trigger instant-lock gesture
```

---

## Checkpoint ("G1 — Secure core")

- [ ] DB is encrypted at rest; unreadable without the Enclave-gated key (proven by test).
- [ ] App-lock works on a **physical device** (biometric + PIN fallback + timeout + background lock).
- [ ] Switcher blur prevents snapshot leakage; neutral icon/name switch works and is **non-deceptive** (Guideline 2.3 safe).
- [ ] All tables carry sync metadata; migration round-trip test green; **no shipped migration is ever edited** going forward.
- [ ] Encrypted export + full-delete verified.
- [ ] All privacy invariant tests green (release blocker).
- [ ] App runs fully in airplane mode.

---

## Validation steps

1. `make verify` → green (lint, unit, snapshot, privacy invariants).
2. `make test-ui` → lock flow passes on simulator.
3. On a **real iPhone**: enroll Face ID, confirm lock/unlock, timeout lock, background→blur→gate.
4. Inspect the DB file on disk (e.g., via container) → confirm it's ciphertext, not readable SQL.
5. Export a backup, full-delete, relaunch → app starts clean; backup importable with passphrase.
6. Airplane mode → app fully functional.

---

## Exit criteria → Phase 2

Secure substrate verified on a physical device, repositories stable, all G1 checkpoints met. Phase 2 builds tracking on top of these repositories without touching crypto.
