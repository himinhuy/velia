import SwiftUI
import VeliaDesignSystem

/// Full-screen lock gate shown whenever the app is locked. Also doubles as the app-switcher cover,
/// so no health data is visible in the multitasking snapshot.
struct LockScreenView: View {
    let lock: LockManager

    var body: some View {
        ZStack {
            Theme.screen.ignoresSafeArea()
            VStack(spacing: Theme.spacingLarge) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text("Velia")
                    .font(.largeTitle.bold())
                Text("Riêng tư, của riêng bạn.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await lock.authenticate() }
                } label: {
                    Label(lock.biometryLabel, systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}
