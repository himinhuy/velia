# Velia — Build & Device Runbook

> **Native Swift/SwiftUI app — no Expo, no Metro, no dev server.** A Release build embeds everything
> and runs fully standalone on the device, disconnected from your Mac. There is nothing to "detach"
> from — native apps don't depend on a bundler server the way Expo/React Native does. The only
> requirements to run on a real device are: an Xcode project, Apple code-signing, and the device.

What the app shows today: the **on-device prediction engine demo** (`PredictionDemo` in VeliaCore) —
a real, computed next-period window + confidence. Enough to manually verify the engine on-device
before tracking/storage UI lands (Phases 2–3).

---

## What builds

| Part | Build system | Status |
|---|---|---|
| `VeliaCore` (engine, persistence, backup, demo) | plain SwiftPM | ✅ builds & tests now (`make test`, 31 tests) |
| iOS app (engine + UI subset) | Xcode (Route A or B below) | ⏳ builds once you have Xcode; GRDB/encryption modules deferred |
| `VeliaData`/`VeliaSecurity`/`VeliaHealth` | Xcode + SQLCipher GRDB | 🧱 scaffolds, excluded from the build until configured |

The app graph is intentionally trimmed to **app → VeliaFeatures → VeliaDesignSystem → VeliaCore** so it
compiles and runs **today** on the verified engine. Encryption/DB modules are re-added in Phase 1 finish.

---

## Route B — fastest, no Tuist (recommended to get a Release build on device now)

Xcode generates a correct project, so this is the most reliable path.

1. **Xcode → File → New → Project → iOS → App.** Name `Velia`, Interface **SwiftUI**, language **Swift**.
   Save it anywhere (e.g. inside this repo as `VeliaApp/`).
2. **Add the engine as a local package:** File → Add Package Dependencies → **Add Local…** → select the
   `VeliaCore/` folder in this repo → add the **VeliaCore** library to the app target.
3. **Replace `ContentView.swift`** with:
   ```swift
   import SwiftUI
   import VeliaCore

   struct ContentView: View {
       private let prediction = PredictionDemo.sample()
       var body: some View {
           VStack(spacing: 12) {
               Text("Velia").font(.largeTitle.bold())
               Text("Dự đoán chu kỳ chính xác — riêng tư, của riêng bạn.")
                   .font(.subheadline).foregroundStyle(.secondary)
                   .multilineTextAlignment(.center)
               VStack(spacing: 8) {
                   Text(PredictionDemo.sampleSummary()).font(.headline)
                       .multilineTextAlignment(.center)
               }
               .padding()
               .frame(maxWidth: .infinity)
               .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
               Text("On-device · no account · no network").font(.caption2).foregroundStyle(.tertiary)
           }
           .padding()
       }
   }

   #Preview { ContentView() }
   ```
4. **Signing:** select the project → target **Velia** → Signing & Capabilities → check *Automatically
   manage signing* → pick your Team (free Apple ID works for personal device installs).
5. **Release scheme:** Product → Scheme → Edit Scheme → **Run → Build Configuration = Release**.
6. **Run on device:** plug in the iPhone, select it as the run destination, ⌘R.
7. **Prove standalone:** once installed, **unplug the Mac and enable Airplane Mode** — the app still
   launches and shows the prediction. That's the real independence test.

This reuses the *exact* verified engine code; only the app shell is new.

---

## Route A — Tuist (project-as-code, full multi-module graph)

Use this once you want the structured modules. Requires installing Tuist on your Mac.

```bash
# install Tuist (pick one your environment allows):
brew install tuist            # if you use Homebrew
# or: mise install tuist      # if you use mise

export DEVELOPMENT_TEAM=XXXXXXXXXX   # your Apple Developer Team ID
make bootstrap                        # tuist install && tuist generate
open Velia.xcworkspace
```
Then set Release config + device as in Route B steps 5–7. `Project.swift` already declares automatic
signing reading `DEVELOPMENT_TEAM` from the environment.

CLI archive (for TestFlight / ad-hoc):
```bash
xcodebuild -workspace Velia.xcworkspace -scheme Velia -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Velia.xcarchive archive
```

---

## Verification checklist
- [ ] App installs on a physical iPhone under the **Release** configuration.
- [ ] **Airplane mode + Mac disconnected** → app launches and shows the predicted window → standalone ✅.
- [ ] Prediction text matches `swift run velia-bench`-style engine behavior (sane near-future window).
- [ ] (Later, with encryption wired) app-lock: background → relaunch → Face ID/passcode gate
      (real device only — Simulator has no Secure Enclave / Face ID).

---

## Phase 1 finish (to re-enable encryption in the build)
1. Add a **SQLCipher-enabled GRDB** package (vanilla GRDB lacks `usePassphrase`).
2. Re-add `VeliaData`/`VeliaSecurity`/`VeliaHealth` targets in `Project.swift` (deps noted there).
3. Fix any GRDB API drift in `Modules/VeliaData/*`; verify the Secure-Enclave key flow on-device.
4. Add a slow passphrase KDF (PBKDF2/Argon2id) for `BackupCodec` export.
5. Wire the repositories + app-lock into the app; add app-switcher blur + neutral icon.
