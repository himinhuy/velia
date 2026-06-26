import SwiftUI
import VeliaDesignSystem

/// Launch gate when there are multiple profiles or the chosen profile has a PIN. Pick a profile;
/// if it's PIN-protected, enter the PIN. All on-device — no account, no network.
struct ProfileGateView: View {
    @Environment(ProfileStore.self) private var profiles
    @State private var pinFor: ProfileInfo?

    var body: some View {
        if let pinFor {
            PINEntryView(
                title: profiles.displayName(pinFor),
                subtitle: L2("Nhập mã PIN", "Enter your PIN"),
                onSubmit: { pin in profiles.enter(pinFor.id, pin: pin) },
                onCancel: { self.pinFor = nil }
            )
        } else {
            picker
        }
    }

    private var picker: some View {
        VStack(spacing: Theme.spacingLarge) {
            Spacer()
            Image(systemName: "person.2.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Velia").font(.largeTitle.bold())
            Text(L2("Chọn hồ sơ", "Choose a profile")).font(.subheadline).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(profiles.profiles) { info in
                    Button {
                        if info.hasPIN { pinFor = info } else { profiles.enter(info.id, pin: nil) }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2).foregroundStyle(Theme.accent)
                            Text(profiles.displayName(info)).font(.headline).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: info.hasPIN ? "lock.fill" : "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .veliaCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.screen)
    }
}
