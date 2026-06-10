# Velia — Product Specification (v0.2)

> A privacy-first, accuracy-led menstrual & reproductive health tracker. **Local-first, iOS-first, Vietnam-first.** Honest about what it knows, warm to use, and built to genuinely win irregular-cycle users.

> **v0.2 supersedes v0.1.** The original draft described a US, cross-platform, privacy-manifesto product. This version reflects the strategic pivot decided in `docs/discussion.md` (the grill-me decision log): **Vietnam-first launch, iOS-only at start, accuracy as the wedge, privacy reframed as discretion.** Where v0.1 conflicts, v0.2 wins. The full rationale for each decision lives in `docs/discussion.md`.

---

## 1. Positioning

**Vietnam (launch):**
> **"Dự đoán chu kỳ chính xác — kể cả khi chu kỳ của bạn thất thường. Riêng tư, ấm áp, của riêng bạn."**
> *("Accurate cycle predictions — even when your cycle is irregular. Private, warm, yours.")*

The VN wedge is **accuracy for irregular cycles + Vietnamese-fluent warmth + discretion** (people around you can't snoop), *not* an anti-surveillance manifesto.

**United States (later, the revenue engine):**
> **"The period tracker that physically cannot hand over your data — because we never have it."**

The strong "uncompellable" privacy claim is **reserved for the US launch**, where it both resonates and is proven by an independent audit (see §10).

**The through-line:** be the tracker that is *both* the most accurate on irregular cycles *and* the most honest about its own uncertainty. Honesty/calibration is a feature, not a caveat.

---

## 2. Strategy: the sequence

We win a narrow beachhead, then expand along two axes (scale, then revenue):

1. **Beachhead — Vietnam, iOS, premium urban women.** Highest willingness-to-pay slice; most likely to own an Apple Watch (wrist temp → better fertility accuracy); cleanest tech surface (HealthKit, Secure Enclave, Core ML). This is a **traction/learning** market, not a revenue market.
2. **Scale — Vietnam, Android.** Where the volume is. Requires an Android build and localized discretion features.
3. **Revenue — United States.** Higher ARPU (~$40/yr), and the home of the privacy wedge. Requires the security audit + open-sourced crypto.

**We do not try to beat Flo on breadth.** We win the irregular-cycle and discretion-conscious segments incumbents serve poorly.

Persona anchor (VN beachhead): *"Linh, 31, urban professional in HCMC, iPhone user. Her cycles became unpredictable and the English period apps she's tried assume a tidy 28 days and feel foreign. She wants predictions that respect how irregular she actually is, in her own language, that her boyfriend can't casually open."*

---

## 3. Core principles (non-negotiable)

- **Accuracy with honesty.** We win on irregular-cycle prediction *and* on never faking confidence. Every prediction ships with a calibrated confidence range. When we can't predict well, we say so.
- **Local-first.** All health data lives encrypted on the device. Fully functional offline, no account required.
- **Discretion by default.** Biometric lock on, app-switcher blur, neutral icon/name option. Privacy from the people around you, first.
- **Honest claims only.** In Vietnam we claim *on-device encryption + discretion* — never "uncompellable/can't be subpoenaed" until that is independently audited (US milestone).
- **Revenue from users, not surveillance.** No ad SDKs, no data brokers, no third-party analytics on health data. Ever.
- **We never train on your data.** Model improvements come from licensed/public clinical datasets, not from harvesting users.

---

## 4. The accuracy engine (the moat — build and validate this FIRST)

This is the make-or-break differentiator and the **first thing built**, in isolation, before any app UI (see §10 phasing and the §11 go/no-go gate).

### 4.1 Approach (three horizons)
- **MVP (A):** transparent on-device math — a recency-weighted Bayesian model. No data harvesting. Honesty/calibration is the headline.
- **V2 (B):** a small on-device ML model (Core ML) for irregular cycles, **trained once, offline, on licensed/public clinical datasets**, shipped frozen. Improved only via new licensed data — never from users.
- **Later/explore (C):** privacy-preserving learning from the user base (federated learning / differential privacy) — only after a security audit.

### 4.2 MVP model spec
- **Per-user posterior over cycle-length distribution** (not a point estimate). The posterior *is* the confidence interval, so calibration falls out naturally.
- **Heavy-tailed likelihood** (Student-t / log-normal) → robust to one-off outlier cycles (illness, stress).
- **Recency / exponential weighting** → tracks non-stationary cycles (perimenopause lengthening, postpartum return).
- **Explicit anovulatory / skipped-cycle handling** → detect and flag/down-weight rather than averaging a 60-day "cycle" in raw (critical for PCOS & perimenopause).
- **Ovulation = its own, wider-interval estimate** — never naive "14 days before next period" back-counting.
- **Quantitative honesty gate** → when posterior interval width exceeds a threshold or a regime change is detected, switch to explicit "not enough confidence to predict yet — here's your range" mode.

### 4.3 How accuracy is defined and proven
- **Primary metric: confidence-interval calibration/coverage** (does "Mar 12–15" contain the true date at the target rate?). This is the headline claim — lower regulatory risk and the one place we're unambiguously better than data-harvesters.
- **Secondary metric: median absolute error (days).**
- **Benchmark:** acquire a **public irregular-cycle dataset** for offline validation *before* building. (Doubles as the seed corpus for V2's licensed-data pipeline.)
- **"Superior" defined concretely:** beat the naive-28-day and simple-average baselines on the **high-variance (irregular) subset**.

### 4.4 Cold-start (Month 1, when the user has no history)
- **Onboarding intake** seeds a prior on day one: last 1–3 period dates, typical cycle length, known conditions, age. (Accepted despite added signup friction.)
- **Segment population priors** as the Bayesian starting point (PCOS / perimenopause / postpartum distributions — must be sourced & validated).
- **Front-load logging + education value** so retention doesn't depend on prediction firing.
- **Retention mechanic:** show a prediction from day one with an honestly **wide** confidence range that **visibly narrows as the user logs** — "the more you track, the sharper it gets." Honesty becomes the engagement loop.

### 4.5 Fertility / ovulation
- Ships **deliberately low-confidence for irregular users at MVP** — not faked.
- **VN fertility signal (no named wearables):** manual **BBT + cervical-mucus + LH-strip** logging, plus whatever **HealthKit / Health Connect** surfaces from whatever device the user has. (Accepts more daily logging burden in exchange for honesty.)
- **Named-wearable integrations (Oura / Garmin / Apple Watch dedicated) are a US-tier feature** — those devices and that ARPU live in the US, not VN.

---

## 5. Feature scope

### 5.1 MVP (iOS-only, Tier-1 wellness, Vietnam)
**Tracking**
- Log period start/end, flow intensity, spotting
- Symptom, mood, energy, sleep, sex (protected/unprotected), discharge logging
- Manual fertility signals: BBT, cervical mucus, LH strips
- Free-text private notes; user-defined custom trackable tags

**Prediction & insight**
- Next-period prediction with **visible, calibrated confidence range**
- Fertile-window estimate, explicitly low-confidence for irregular users (see §4.5)
- Cycle-phase view (menstrual / follicular / ovulatory / luteal) with plain-language Vietnamese explanations
- Honest "too irregular to predict confidently" mode (§4.2)
- Onboarding intake that seeds the model (§4.4)

**Privacy & discretion**
- Works fully offline, no account required
- On-device encryption at rest (SQLCipher), key in Secure Enclave
- **Discretion suite (Apple-compliant):** optional neutral icon + neutral display name (abstract, *not* a deceptive clone); mandatory-by-default biometric/PIN lock; app-switcher blur + lock-on-background; one-gesture instant lock/decoy screen
- One-tap encrypted export and one-tap full delete

**UX & content**
- Calendar + timeline views
- Local reminders (period, pill/contraception, log nudges)
- Warm, clear, non-clinical SwiftUI design
- **Native Vietnamese content** (UI + cycle education), informational-not-diagnostic, with disclaimers + per-claim source citations (§8)

### 5.2 V2 (moat-deepeners — by axis)
- **Zero-knowledge E2E sync** across devices (gated to the US milestone; preceded by audit + open-sourcing)
- **Named-wearable integration** (Apple Watch / Oura / Garmin temp + HR), processed on-device — **US tier**
- **Improved irregular-cycle ML model** (Core ML), trained on licensed/public data (§4.1-B)
- **Android build** (Kotlin/Compose) for VN scale
- **TTC / pregnancy mode** and **perimenopause / menopause mode** — *Tier-2/3, regulatory-gated*
- **Condition support modules** — PCOS, endometriosis (symptom patterns, doctor-visit summaries) — framed as *symptom tracking, not diagnosis*
- **Birth-control adherence** tracking — *Tier-2/3, regulatory-gated*
- **US launch** (privacy manifesto positioning, ~$40/yr)

### 5.3 Later / explore
- Privacy-preserving aggregate research (opt-in, federated/DP) — post-audit only
- Shareable doctor report (PDF, generated on-device)
- Partner/shared view (E2E, opt-in)
- Deeper Android-only discretion (true icon/name swap, hidden-launcher) for VN scale

---

## 6. Differentiation vs. the field

| Dimension | Flo | Clue | Stardust | **Velia** |
|---|---|---|---|---|
| Data location | Cloud | Cloud (GDPR) | Cloud | **On-device (E2E sync later)** |
| Can comply w/ subpoena | Yes | Yes | Yes (states it will) | **No — no readable data held** (claimed only once audited, US) |
| Irregular-cycle accuracy | Weak | Weak | Weak | **Core focus, validated against a benchmark** |
| Honesty about uncertainty | Low | Low | Low | **Calibrated confidence ranges = headline** |
| Vietnamese-native UX/content | No | No | No | **Yes (launch market)** |
| Discretion (people around you) | Weak | Weak | Themed | **Hero feature** |
| Monetization | Ads/data + sub | Subscription | Subscription | **User-funded, no ad SDKs** |

Honest gaps to plan around: local-first makes cross-device features and server-side analytics harder; we enter against players with 70M+ MAU and large budgets. We don't out-spend — we out-trust and out-accurate them in the segments they neglect, in a market (VN) we know.

---

## 7. Technical architecture

### 7.1 Stack (decided)
- **Platform:** **iOS-only at launch. Native Swift / SwiftUI.** (Android = Kotlin/Compose later for VN scale.)
- **Local DB:** **GRDB + SQLCipher** (whole-file encryption). All PHI lives here.
- **Encryption at rest:** key in the **Secure Enclave / Keychain** (CryptoKit), unlocked by biometric/PIN.
- **Prediction model:** **on-device only.** MVP = the recency-weighted Bayesian model (§4.2). V2 = a small **Core ML** model trained offline on licensed/public data. **No cloud inference on health data, ever.**
- **Wearable/sensor surface:** **HealthKit** (incl. Apple Watch wrist temperature) for VN; dedicated wearable SDKs are a US-tier add.

Rationale: the hardest requirements (Secure Enclave, Keychain, HealthKit, Core ML, polished warm UI) are all native-iOS strengths. Cross-platform reuse is deferred because Android arrives later and much of the value (crypto, Health Connect, ML) is platform-specific regardless. Trade-off accepted: an Android UI rewrite later, with logic/crypto/model kept portable.

### 7.2 Data model — sync-ready, sync-less
Sync is deferred, but the schema is built so it can be added without a painful migration:
- **Client-generated UUID primary keys** (never autoincrement).
- **Sync metadata on every row from day one:** `updated_at`, `device_id`, soft-delete tombstone (`deleted_at`). **No hard deletes.**
- **Fine-grained, independently mergeable rows** (one row per entry, not a fat per-day JSON blob).
- **Current-state tables** (not event-sourcing) + the metadata above.
- **Eventual conflict model: last-write-wins (LWW)** per record (accepts rare-edge data-loss for far less complexity than CRDTs).
- **No sync networking code is written now** — only these affordances.

### 7.3 Zero-knowledge sync (V2, US milestone)
- Encryption key derived from a user passphrase (never sent to server) + Secure-Enclave key.
- Server stores only opaque ciphertext blobs keyed by an anonymous account ID; no schema knowledge of contents.
- Client-side LWW merge after decryption.
- Identity decoupled from email where possible (random recovery code) to minimize identity surface.
- **Recovery UX is a hard design problem** (lost passphrase = lost data) — solve before shipping.

### 7.4 What the server is allowed to know
Nothing about cycles, symptoms, or health. Only: encrypted blobs, sync timestamps, billing status (via app stores where possible). Note: VN's data-localization law (Decree 53) is a *non-issue* by design — there's nothing readable to localize.

### 7.5 Compliance posture
- **MVP = Tier-1 wellness** (cycle *estimates*, no contraceptive/diagnostic claims). Explicit "not for contraception" where fertile window is shown.
- **Tier-2/3** (fertility-for-conception, contraception, condition diagnosis) is gated behind a deliberate, funded, legally-reviewed decision. Condition modules are framed as *symptom tracking, not diagnosis*.
- GDPR-by-design (data minimization; delete = trivial because it's local) — relevant for the later US/EU expansion.
- Get regulatory + legal advice before any Tier-2/3 claim or EU entry.

---

## 8. Content & trust

- **Native Vietnamese authoring** (not machine translation) for all UI, cycle education, and marketing content.
- **Informational-not-diagnostic framing** everywhere; standard disclaimer ("tham khảo ý kiến bác sĩ").
- **Per-claim source citation discipline** baked into the content pipeline — this is what the "accurate/honest" brand rests on.
- **Clinician review is optional** (decision logged). **Residual risk:** without a clinician, the accuracy brand rides entirely on self-sourced citations; one viral wrong claim in a women's-health app is a brand-killer. Reconsider as soon as budget allows.
- **Trust verification (US milestone):** independent security audit + open-source the **crypto/sync layer only**, tied to the E2E-sync release — *that's* when the strong privacy claim turns on.

---

## 9. Monetization

- **Free core tracking forever.**
- **Vietnam:** paid tier at **100K VND/year** unlocking accuracy/insight features — advanced irregular-cycle insights, condition modules, doctor-report PDF (wearable integration is US-tier). VN is a **traction/learning** market; revenue is expected to be negligible by design.
- **United States (revenue engine):** ~$40/yr subscription, privacy-wedge positioning, with the wearable + sync features as premium unlocks.
- **Hard rule:** no ad SDKs, no data sale, ever. The business model *is* the marketing.
- *(Open tension, logged: 100K VND/yr economics make VN revenue-negligible; the model depends on the US fast-follow actually happening.)*

---

## 10. Build roadmap (solo founder, build-first)

Realistic honest timeline: **~8 months to public launch** (solo; build and content cannot run in parallel).

- **Weeks 0–4 — Prediction engine (the gate).** Build the Bayesian engine in isolation, validate against the public irregular-cycle benchmark. **Go/no-go:** if it can't beat naive baselines on the irregular subset with calibrated intervals, **kill or pivot before building the app.**
- **Weeks 4–8 — Core app.** Encrypted DB (sync-ready schema), logging, calendar/timeline, onboarding intake, discretion suite.
- **Weeks 8–12 — Prediction UI + Vietnamese content + manual fertility logging + polish.**
- **Weeks 12–16 — Closed beta**, cohort recruited from VN Facebook health groups (also tunes the engine and cold-start).
- **Then:** public VN iOS launch → ramp content/growth → Android (VN scale) → US (revenue, preceded by audit + open-sourcing + E2E sync).

**Distribution (no ad budget, no in-app ads):** organic short-form (TikTok/Reels), Vietnamese health/beauty/mom KOLs, Facebook Groups (PCOS/TTC/perimenopause), Vietnamese ASO. Content angle = irregular-cycle/PCOS education + the honesty hook ("the app that admits when it doesn't know"). **Content creation is a founding capability**; in a build-first model, lightly seed an audience while building, then ramp hard at beta.

---

## 11. Key risks & open questions

- **The engine gate (§10).** Highest risk. The entire thesis dies here if the math can't beat naive baselines on irregular cycles. Resolve in weeks 0–4.
- **Solo capacity.** The single largest threat to the ~8-month timeline. **Highest-leverage de-risking move: recruit a Vietnamese content/growth co-founder** — more than any technical decision.
- **Build-first defers market validation ~6 months**, in tension with the stated traction/learning goal. Mitigate by seeding a content audience early.
- **No clinician** → accuracy brand rides on self-citations alone (§8).
- **VN unit economics** → near-zero revenue by design; depends on the US fast-follow.
- **LWW** can silently lose a concurrent edit in rare multi-device cases.
- **Cold-start honesty vs. retention** → irregular users (best-fit) get the longest low-confidence period; the narrowing-range mechanic must carry retention.
- **Tier creep** → TTC/birth-control/condition modules must not drift in without a funded regulatory decision.

---

## 12. What to validate before writing much code

1. **Acquire a public irregular-cycle benchmark dataset** (gate input + V2 seed).
2. **Run the weeks-0–4 engine gate** — go/no-go on the whole thesis.
3. **Source & validate segment population priors** for cold-start.
4. **Confirm the founder can author Vietnamese women's-health content** — if not, that's the co-founder gap to fill first.
5. **Decide whether to keep clinician review optional** given the brand risk.

---

*Decision rationale and the full grill-me trade-off log live in `docs/discussion.md`. Next deliverables available on request: detailed DB schema, the prediction-engine algorithm spec, the benchmark/validation plan, or wireframes for the VN iOS MVP.*
