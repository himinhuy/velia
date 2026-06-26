# Velia — Grill-Me Decision Log

> Outcome of a relentless design interview stress-testing `docs/prd.md`.
> Date: 2026-06-05. Format: each decision = the tension surfaced, the options, the recommendation, and the **locked answer**.

This document **supersedes large parts of the PRD**, which was written for a US, cross-platform, privacy-first launch. The decisions below pivot the product to a **Vietnam-first, iOS-first, accuracy-led** launch. Where this doc and the PRD conflict, **this doc wins** until the PRD is rewritten.

---

## TL;DR — the new spine

- **Market:** Vietnam first (premium urban iPhone women), then Android for VN scale, then **US as the revenue engine**.
- **Wedge:** accurate irregular-cycle prediction + Vietnamese-fluent warmth + discretion (not the US "anti-surveillance" manifesto).
- **Platform:** iOS-only at launch. **Native Swift/SwiftUI.**
- **Privacy:** local-first, on-device encryption — reframed as a *discretion/trust* feature. The strong "uncompellable / can't be subpoenaed" claim is **reserved for the audited US launch.**
- **Monetization:** free core forever; paid tier (100K VND/yr) unlocks accuracy/insight features. VN = **traction/learning**, not revenue.
- **The gate:** the prediction engine must beat naive baselines on a public irregular-cycle benchmark in **weeks 0–4**, *before* the app is built around it. If it fails, the thesis is dead.
- **Team:** **solo founder.** Build-first, market later. Honest timeline **~8 months to public launch.** Flagged top risk: missing Vietnamese content/growth co-founder.

---

## Decisions (in interview order)

### Q1 — Core contradiction: "never have the data" vs. "best irregular-cycle predictions"
You can't train modern accuracy models on data you've promised never to collect.
**Locked:**
- **(A) MVP:** accuracy from transparent on-device math (+ sensor fusion later), not data harvesting; honesty/calibration is the feature.
- **(B) V2 accuracy engine:** train once, offline, on **licensed/public clinical datasets**, ship frozen on-device; improve via new licensed data — never from users.
- **(C) Later/explore only, post-audit:** privacy-preserving learning (federated / differential privacy).
- **Gap named:** acquiring licensed clinical datasets for (B) is nowhere in the current budget/roadmap and must be planned before V2.

### Q2 — Proving "superior accuracy" with no data of your own
"Superior" must be measurable and defensible.
**Locked:**
- **Two metrics:** (1) median absolute error in days; (2) **confidence-interval calibration/coverage** (does "Mar 12–15" contain the real date ~target% of the time).
- **Headline claim = calibration**, not raw point-accuracy (lower regulatory risk, the one place you're unambiguously better than data-harvesters).
- **Acquire a public irregular-cycle benchmark dataset before building** the engine; it doubles as the seed for the Q1-B pipeline.
- **"Superior" defined concretely:** beat naive-28 and simple-average baselines on the high-variance (irregular) subset.

### Q3 — Regulatory tier + launch market
Marketing claims determine whether you become a regulated medical device.
**Locked:**
- **Markets:** US **and** Vietnam (later refined — see Q4/Q5: Vietnam *first*).
- **Tier 1 (unregulated wellness) for MVP:** period/cycle *estimates* with confidence ranges, explicit "not for contraception," no diagnosis.
- **Tier 2/3 (fertility-for-conception, contraception, condition diagnosis) gated** behind a deliberate, funded regulatory decision with legal sign-off. Condition modules must be framed as *symptom tracking, not diagnosis.*

### Q4 → Q5 — Vietnam-first reframes the product (PRD §1, §7 invalidated)
The US post-Dobbs privacy pitch doesn't drive adoption in Vietnam.
**Locked:**
- **(a) VN positioning:** lead with **accuracy-for-irregular-cycles + Vietnamese-fluent warmth**; **discretion (app-lock/panic-hide)** as the privacy hook — *not* the Dobbs/anti-surveillance line.
- **(b) Price:** **100K VND/year** subscription (free core forever). *(Recommendation was a one-time lifetime unlock; user overrode — see Q6 economics.)*
- **(c) Build re-order:** front-load prediction + Vietnamese localization; **defer zero-knowledge E2E sync out of MVP.**
- The US-style privacy manifesto becomes a **secondary discretion feature** for the VN launch.

### Q6 — Unit economics at 100K VND/yr
~$3.90/yr gross → ~$2.70–3.30 net; low VN paid conversion (2–4%) ⇒ blended ~$0.05–0.13/active/yr. Needs ~500K–1M+ actives to be a business.
**Locked:**
- **Paid tier unlocks** (per recommendation): advanced irregular-cycle insights + wearable integration (US) + condition modules + doctor-report PDF. **Core tracking free forever.**
- **Vietnam = traction/learning market, not revenue.** **US fast-follow at ~$40/yr (privacy wedge + higher ARPU) is the actual revenue engine.**

### Q7 — Cold-start (new user, zero history; irregular users worst-hit)
**Locked (all three, layered):**
- **(A) Onboarding intake:** last 1–3 period dates, typical cycle length, known conditions, age → seeds a prior on day one. *(Accepted despite signup friction.)*
- **(C) Segment population priors** as the Bayesian starting point. *(Must source/validate the aggregate clinical assumptions — ties to Q1-B / Q2 data work.)*
- **(B) Front-load logging + education value** so retention doesn't depend on prediction firing.
- **Mechanic:** show a prediction from day one with an **honestly wide confidence range that visibly narrows as the user logs** — narrowing = the retention loop. Honesty principle becomes the engagement engine.

### Q8 — The prediction engine spec (the moat; build first)
Naive mean-of-last-N fails exactly on the target cycles.
**Locked engine spec:**
- **Recency-weighted Bayesian model**, per-user **posterior over cycle-length distribution** (the posterior *is* the confidence interval → calibration falls out).
- **Heavy-tailed likelihood** (Student-t / log-normal) for outlier robustness.
- **Explicit anovulatory/skipped-cycle handling** (detect/flag/down-weight rather than averaging raw).
- **Exponential/recency weighting** for non-stationarity (perimenopause, postpartum).
- **Ovulation = its own wider-interval estimate**, not naive back-counting.
- **Quantitative "too irregular to predict" honesty gate.**
- **Validate against the Q2 benchmark before building UI.**
- **Accepted:** fertility/ovulation ships **deliberately low-confidence** for irregular users at MVP (no wearables yet), not faked.

### Q9 — Wearables reality in Vietnam
Oura/Garmin ≈ zero; cheap bands (Mi/Huawei/Amazfit) have closed/region-locked APIs and no reliable temp feed.
**Locked:**
- **Named-wearable SDK integration (Oura/Garmin/Apple Watch) → US tier.**
- **VN fertility signal:** manual **BBT + cervical-mucus + LH-strip** logging, plus whatever **HealthKit / Health Connect** surfaces. *(Accepted: more daily logging burden on VN users for good ovulation predictions.)*

### Q10 — Trust verification: audit + open-source crypto
Unverified strong privacy claims are a liability — but the audit is costly and there's no sync layer to audit yet.
**Locked (tiered trust plan):**
- **VN MVP:** no paid audit. Nail discretion features + on-device SQLCipher + one-tap delete. Honest copy only.
- **Before US launch / before E2E sync ships:** commission **independent security audit** + **open-source the crypto/sync layer only.**
- **Hard copy rule:** in VN, market **discretion + on-device encryption**; do **NOT** make the "uncompellable / can't be subpoenaed" claim until audited. Strongest privacy line reserved for US (true-by-design + proven).

### Q11 → Q12 — Platform + tech stack
User chose **iOS-first** (surfaced contradiction: VN is Android-majority).
**Locked:**
- **iOS-first reframes the target = premium urban VN women** (highest willingness-to-pay; most likely to own Apple Watch Series 8+ wrist-temp). **Then Android for VN scale, US for revenue.** User-test and market to *that* slice (Instagram/iOS-leaning), not the mass market.
- **Stack: native Swift/SwiftUI.** Not React Native, not Flutter.
  - **GRDB + SQLCipher** (encrypted local DB), **CryptoKit + Secure Enclave** (keys), **HealthKit** (wearable/temp), **Core ML** (V2 on-device model).
  - Rationale: hardest requirements are native-iOS strengths; cross-platform reuse benefit deferred (Android comes later and is platform-specific anyway).
  - **Accepted trade-off:** Android will need a Kotlin/Compose UI rewrite later (logic/crypto/model portable if disciplined).

### Q13 — Distribution (no ad budget, no in-app ads)
PRD's US channels are irrelevant in VN.
**Locked:**
- Channels: **organic short-form (TikTok/Reels) + Vietnamese health/beauty/mom KOLs + Facebook Groups (PCOS/TTC/perimenopause hội nhóm) + Vietnamese ASO.** US-centric channels dropped for now.
- **Content angle = PCOS/irregular-cycle education + the honesty/calibration hook** ("the app that admits when it doesn't know").
- **Content creation is a founding-team capability from day one**, not a post-launch task. **Gap named:** if no one can produce VN women's-health content, that's a hiring/co-founder gap.
- Recruit beta cohort from FB health groups (also feeds Q2 benchmark + Q7 tuning).

### Q14 — Discretion features (now the hero privacy feature) — Apple constraints
A fake-app disguise / panic-vanish isn't feasible/compliant on iOS.
**Locked (honest, Apple-compliant scope):**
- Optional **neutral app icon + neutral display name** (abstract, *not* a deceptive clone).
- **Mandatory-by-default biometric/PIN lock.**
- **App-switcher blur + lock-on-background.**
- **One-gesture instant lock/decoy screen.**
- **Dropped:** "disguised as another app / panic-vanish" on iOS (App Store rejection + over-promise risk). Heavier hiding reserved for Android later.
- Market as "private and discreet," **not** "invisible/undetectable."

### Q15 — Data model: sync-ready but sync-less
Sync is deferred, but retrofitting it onto a naive schema is brutal.
**Locked:**
- **UUID primary keys** (client-generated), not autoincrement.
- **Sync metadata on every row now:** `updated_at`, `device_id`, soft-delete tombstone (`deleted_at`); **no hard deletes.**
- **Fine-grained, independently mergeable rows** (one row per entry, not fat per-day JSON).
- **Current-state tables** (not event-sourcing) + the metadata above.
- **Eventual conflict model = last-write-wins (LWW)**, not CRDTs (accepted: rare-edge data-loss risk for far less complexity).
- **Write zero sync networking code now** — only the schema affordances.

### Q16 — Medical content accuracy + liability (Vietnamese, at scale)
"Accurate/honest" brand + health content = trust and Tier-1 liability risk.
**Locked:**
- **(1) Clinician reviewer: OPTIONAL** *(user overrode the "required" recommendation).* **Residual risk flagged:** without a clinician, the accuracy brand rests entirely on self-sourced citations; one viral wrong claim in a women's-health app is a brand-killer.
- **(2) Content rule ACCEPTED:** native Vietnamese authoring (not machine translation) + **informational-not-diagnostic framing** + disclaimer ("tham khảo ý kiến bác sĩ") + **per-claim source citation discipline.** Bake into the content pipeline; protects Tier-1 posture at the content layer.

### Q17 — Scope + sequencing
**Locked:**
- **MVP (iOS, single-platform, Tier-1):** core logging + calendar/timeline + **validated Bayesian prediction engine with honest confidence ranges** + onboarding intake + discretion (lock/blur/neutral icon) + Vietnamese-native UX/content + manual fertility logging + sync-ready encrypted DB.
- **Deferred:** E2E sync, named-wearable SDKs, audit/open-source, condition modules, TTC/perimenopause modes.
- **Sequencing gate ACCEPTED:** **weeks 0–4 = prediction engine in isolation**, validated against the public benchmark. **If it can't beat naive baselines on the irregular subset, kill/pivot before building the app.**
- Suggested phasing: wk0–4 engine gate → wk4–8 core app → wk8–12 prediction UI + VN content + manual fertility + polish → wk12–16 closed beta from FB groups.

### Q18 — Solo-founder reality + sequencing
**Locked:**
- **Team: solo founder.**
- **Sequencing: build-first, market later (Option A).**
- **Consequences accepted/flagged:**
  - Honest timeline **~8 months to public launch** (build and content can't run in parallel solo).
  - Build-first means the **week-0–4 engine gate runs against the public benchmark dataset** (not a recruited cohort) — which is why the dataset was acquired early (Q2).
  - The **"traction/learning" goal (Q6) is deferred to beta** rather than running from day one — residual tension noted.
  - **Top flagged risk (whether or not acted on now): the missing Vietnamese content/growth co-founder is the highest-leverage de-risking move available — more than any technical decision in this session.**

---

## Open items / things to do before much code

1. **Acquire a public irregular-cycle benchmark dataset** (gate input + Q1-B seed).
2. **Source/validate segment population priors** (PCOS/perimenopause/postpartum cycle distributions) for cold-start.
3. **Run the weeks-0–4 engine gate.** Go/no-go on the entire thesis.
4. **Decide on the optional clinician** (currently optional; residual brand risk).
5. **Confirm whether the solo founder can author Vietnamese women's-health content** — if not, this is the co-founder gap to fill.
6. **Rewrite the PRD** to reflect this VN-first / iOS-first / accuracy-led pivot.

## Known unresolved tensions (accepted, not eliminated)
- 100K VND/yr economics make VN revenue-negligible by design; revenue depends on the US fast-follow actually happening.
- LWW can silently lose a concurrent edit in rare multi-device cases.
- No clinician = accuracy brand rides on self-citations alone.
- Build-first defers real market validation by ~6 months, in tension with the stated traction/learning goal.
- Solo capacity is the single largest threat to the ~8-month timeline.

---

## Addendum — Tracking-mode picker (2026-06, implementation)
A five-mode picker ("Velia có thể giúp gì cho bạn?") ships, but **Tier-1 posture is preserved** (invariant #6):
- **Functional now:** *Theo dõi kỳ kinh* (period); *Đang muốn có thai* — the **Tier-1 fertility-*awareness*** reframing (emphasis on the existing low-confidence fertile window + manual BBT/cervical-mucus/LH + intimacy logging + a "không phải công cụ tránh thai/chẩn đoán" disclaimer; **no conception-optimization or probability claims, engine unchanged**); *Theo dõi không kinh nguyệt* (no forecast — logging only).
- **Locked "Sắp ra mắt":** *Theo dõi thai kỳ* and *Theo dõi tiền mãn kinh* remain the gated **Tier-2/3** modes from `prd.md:120` / `discussion.md:139` — non-interactive until the funded, legally-reviewed decision.
- Mode is a **non-destructive UI lens** over shared logs (persisted, optional → existing users default to period). Fertility signals stored in `FertilityRecord`; intimacy as a neutral `SymptomRecord`. All logging-only for now (no engine impact pending validation).

## Addendum — "User login" = local profiles + PIN (2026-06, implementation)
A request for "full user login and management" was resolved **without breaking local-first** (invariant #1): no cloud account, no server, no network. Instead:
- **Local profiles**: multiple on-device profiles, each with its **own encrypted data file** (shared device key in Keychain). Create / rename / delete / switch; switching is non-destructive.
- **Optional per-profile PIN** as an *access gate* (salted SHA-256 hash, never plaintext). Data-at-rest is encrypted by the device key regardless; the PIN gates UI access. (A future hardening could derive the per-profile key from the PIN.)
- First run seeds a single default profile that inherits the legacy single-profile data file; a lone PIN-less profile means **no gate** (app opens directly).
- A **real cloud account + sync** remains explicitly out of scope (would transmit PHI off-device → invariant #1) pending a funded, legally-reviewed decision.

## Addendum — Commercialization pivot (2026-06)
The app is moving toward a commercial release. Two earlier "locked" positions are **deliberately superseded** here (recorded so the docs don't contradict the code):

- **"Free core forever" → freemium.** A **7-day free trial** then a **$3/year** subscription gates the app (`SubscriptionManager` + `PaywallView`). Status shows in Settings; one-tap cancel. The purchase is **simulated locally** today — the StoreKit-2 swap point is `SubscriptionManager.subscribe()` (needs a paid Apple Developer account + an auto-renewable product in App Store Connect).
- **"No account" → on-device accounts.** Email/password **auth** (`AuthManager`) gates the app; passwords are **PBKDF2-hashed in the encrypted store** (no plaintext). **Still no server / no network** — invariant #1 (no PHI off-device) is intact. The cloud-auth + Sign-in-with-Apple + email password-reset swap points are `AuthManager.signUp/logIn/resetPassword` (need a backend + paid Apple account).

**Invariant status:** #1 (no PHI off-device) and #6 (no Tier-2/3 claims) remain **intact**. The "free core" and "no account" product positions are intentionally retired; update `prd.md`/`architecture.md` prose when the backend lands. Local profiles + PIN (per-device sub-users) coexist with the account layer.
