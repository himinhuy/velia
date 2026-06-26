import SwiftUI
import VeliaDesignSystem

/// Mode-selection modal (reference design). Shows all five modes; three are functional and two are
/// locked "Sắp ra mắt". On-brand rose accent for the selected card. Used both as onboarding step #1
/// and later via the ≡ menu ("Đổi chế độ").
struct ModePickerView: View {
    /// nil while choosing during onboarding; otherwise the current mode.
    let current: TrackingMode?
    /// "Tiếp tục" in onboarding vs "Đổi chế độ" when switching.
    let isOnboarding: Bool
    let onConfirm: (TrackingMode) -> Void
    let onCancel: () -> Void

    @State private var selection: TrackingMode?

    init(current: TrackingMode?, isOnboarding: Bool,
         onConfirm: @escaping (TrackingMode) -> Void, onCancel: @escaping () -> Void) {
        self.current = current
        self.isOnboarding = isOnboarding
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selection = State(initialValue: current ?? .period)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TrackingMode.allCases, id: \.self) { mode in
                        card(mode)
                    }
                }
                .padding()
                .padding(.bottom, 90)
            }
        }
        .background(Theme.screen)
        .safeAreaInset(edge: .bottom) {
            Button {
                if let selection, selection.isFunctional { onConfirm(selection) }
            } label: {
                Text(isOnboarding ? L2("Tiếp tục", "Continue") : L2("Đổi chế độ", "Switch mode"))
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!(selection?.isFunctional ?? false))
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isOnboarding {
                Button(action: onCancel) {
                    Image(systemName: "xmark").font(.headline)
                        .foregroundStyle(Theme.accent)
                        .padding(10).background(Color(.secondarySystemBackground), in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L2("Velia có thể giúp gì cho bạn?", "What can we help you do?")).font(.title3.bold())
                Text(L2("Bạn có thể thay đổi bất cứ lúc nào.", "You can change this anytime.")).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private func card(_ mode: TrackingMode) -> some View {
        let selected = selection == mode && mode.isFunctional
        return Button {
            guard mode.isFunctional else { return }
            selection = mode
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(mode.title)
                        .font(.title3.bold())
                        .foregroundStyle(selected ? .white : .primary)
                    if !mode.isFunctional {
                        Spacer()
                        Label(L2("Sắp ra mắt", "Coming soon"), systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                }
                Text(mode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(selected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(selected ? Theme.accent : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(selected ? 0 : 0.18), lineWidth: 1)
            )
            .opacity(mode.isFunctional ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!mode.isFunctional)
    }
}
