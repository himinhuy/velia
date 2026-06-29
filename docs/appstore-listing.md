# Velia — App Store listing (draft)

Fill the `[bracketed]` items. Vietnamese-first (primary locale **vi**), with English as a secondary localization.

## Basics
- **App name (30 char max):** `Velia: Cycle & Period Tracker`  ·  VN: `Velia: Theo dõi chu kỳ kinh nguyệt`
- **Subtitle (30 char max):** `Private, accurate, on‑device`  ·  VN: `Riêng tư, chính xác, trên máy`
- **Primary category:** Health & Fitness  ·  **Secondary:** Medical
- **Age rating:** 12+ (infrequent/mild medical/health references)
- **Bundle ID:** `app.velia.ios`

## Promotional text (170 char, updatable without review)
EN: `Track your cycle with predictions that are honest about uncertainty — and stay completely private. No account needed, nothing leaves your device.`
VN: `Theo dõi chu kỳ với dự đoán trung thực về độ chắc chắn — và hoàn toàn riêng tư. Không cần tài khoản, dữ liệu không rời khỏi máy.`

## Description (EN)
Velia is a privacy‑first period and cycle tracker that puts accuracy and discretion first.

WHY VELIA
• Honest predictions — Velia shows a confidence range that narrows as you log, instead of pretending to know the exact day.
• Truly private — your data is encrypted and stays on your device. No account required, no servers, no tracking, no ads.
• Discreet by design — Face ID/passcode lock, an app‑switcher privacy screen, and an optional neutral app icon.

TRACK WHAT MATTERS
• Period days & flow, plus a clear cycle wheel and calendar
• Symptoms: mood, energy, sleep, pain, discharge
• Trying to conceive: fertile‑window view + BBT, cervical mucus and LH logging
• Multiple private profiles, each with its own PIN

GENTLE REMINDERS
• Upcoming period, daily logging, and fertile‑window reminders — all scheduled on your device.

PREMIUM
• A 7‑day free trial, then Velia Premium for $3/year unlocks full access.

Velia is a wellness app — not a contraceptive, fertility‑treatment, or diagnostic tool. Always consult a healthcare professional for medical decisions.

## Description (VN) — *have a native speaker polish before submission*
Velia là ứng dụng theo dõi kinh nguyệt & chu kỳ đặt sự riêng tư và độ chính xác lên hàng đầu.

VÌ SAO CHỌN VELIA
• Dự đoán trung thực — Velia hiển thị khoảng tin cậy và thu hẹp dần khi bạn ghi nhật ký, thay vì giả vờ biết chính xác ngày.
• Riêng tư thật sự — dữ liệu được mã hóa và chỉ ở trên máy của bạn. Không cần tài khoản, không máy chủ, không theo dõi, không quảng cáo.
• Kín đáo — khóa Face ID/mật mã, che màn hình khi chuyển ứng dụng, và biểu tượng trung tính tùy chọn.

GHI LẠI ĐIỀU QUAN TRỌNG
• Ngày hành kinh & lượng kinh, vòng chu kỳ và lịch trực quan
• Triệu chứng: tâm trạng, năng lượng, giấc ngủ, cơn đau, dịch tiết
• Đang muốn có thai: cửa sổ dễ thụ thai + ghi BBT, dịch nhầy, que thử LH
• Nhiều hồ sơ riêng tư, mỗi hồ sơ có mã PIN riêng

NHẮC NHỞ NHẸ NHÀNG
• Kỳ kinh sắp tới, ghi nhật ký hằng ngày, cửa sổ dễ thụ thai — tất cả trên máy.

PREMIUM
• Dùng thử 7 ngày, sau đó Velia Premium 3 US$/năm để mở toàn bộ tính năng.

Velia là ứng dụng chăm sóc sức khỏe — không phải công cụ tránh thai, điều trị hiếm muộn hay chẩn đoán. Hãy tham khảo ý kiến bác sĩ cho các quyết định y tế.

## Keywords (100 char, comma-separated, no spaces)
`period,cycle,menstrual,tracker,ovulation,fertility,PCOS,privacy,calendar,reminder,women,health,kinh nguyệt`

## URLs
- **Privacy Policy:** `[https://velia.app/privacy]`  (host docs/legal/privacy-policy.md)
- **Support URL:** `[https://velia.app/support]`
- **Marketing URL (optional):** `[https://velia.app]`

## In-App Purchase (for the subscription's App Store info)
- **Reference name:** Velia Premium Yearly
- **Product ID:** `app.velia.premium.yearly` · **Group:** Velia Premium · **Duration:** 1 year · **Price:** $3 (USD tier)
- **Display name:** `Velia Premium` · **Description:** `Full access to Velia, billed yearly.`

## Review notes (paste into App Review "Notes")
```
Velia is local-first: all health data is stored encrypted on-device. There is NO server and NO account is required (sign-in is optional; tap "Continue without account").

ACCESS / TRIAL: New installs get a 7-day free trial, then a paywall ($3/year). To review the paid features immediately without waiting, use the Sandbox tester below to purchase the auto-renewable subscription "app.velia.premium.yearly" on the paywall.

SANDBOX TESTER: [email] / [password]

SUBSCRIPTION: Auto-renewable, $3/year, group "Velia Premium". Restore is on the paywall ("Restore purchases"). Cancellation is via the system Manage Subscriptions sheet (Settings → Subscription → Cancel).

ACCOUNT: Optional email/password, stored hashed on-device. Account deletion: Settings → Account → Delete Account.

Velia is a Tier-1 wellness app — no contraceptive/diagnostic claims.
```

## What to test (internal/TestFlight)
- Onboarding → choose mode → cycle wheel + calendar render.
- Trial gating: after 7 days (or DEBUG "expire trial") the paywall blocks; Subscribe (sandbox) → access; Restore works; Cancel opens the system sheet.
- Optional login: "Continue without account"; sign up / log in / forgot / delete account.
- Lock: Face ID/passcode + app-switcher blur; per-profile PIN.
- Language toggle vi/en; neutral app icon; reminders fire.

## Screenshots (6.7" + 6.5" + 5.5" + iPad if supported)
Capture: Cycle ring (Today), Calendar with phases, Track sheet, Paywall, Settings. Use the simulator + the `.storekit` config so the paywall shows a real price.
