import SwiftUI
import VeliaDesignSystem

/// Reusable 4–6 digit PIN entry with an on-screen pad (no system keyboard, so it works on the
/// launch gate). `onSubmit` returns true to accept (verify) or always true (when setting).
struct PINEntryView: View {
    let title: String
    var subtitle: String?
    let onSubmit: (String) -> Bool
    var onCancel: (() -> Void)?

    @State private var pin = ""
    @State private var error = false
    private let maxLen = 6

    var body: some View {
        VStack(spacing: Theme.spacingLarge) {
            if let onCancel {
                HStack {
                    Button(action: onCancel) { Image(systemName: "xmark").font(.headline) }
                        .tint(Theme.accent)
                    Spacer()
                }
            }
            Spacer()
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text(title).font(.title3.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }

            HStack(spacing: 16) {
                ForEach(0 ..< maxLen, id: \.self) { i in
                    Circle()
                        .strokeBorder(error ? .red : Theme.accent, lineWidth: 1.5)
                        .background(Circle().fill(i < pin.count ? Theme.accent : .clear))
                        .frame(width: 14, height: 14)
                }
            }
            .modifier(Shake(animatableData: error ? 1 : 0))

            Spacer()
            pad
            Button {
                submit()
            } label: {
                Text(L2("Xác nhận", "Confirm")).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(pin.count < 4)
            .padding(.horizontal, 24)
        }
        .padding()
        .background(Theme.screen)
    }

    private var pad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(height: 64)
                } else {
                    Button { tap(key) } label: {
                        Text(key)
                            .font(.title.weight(.medium))
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func tap(_ key: String) {
        error = false
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < maxLen else { return }
        pin.append(key)
    }

    private func submit() {
        guard pin.count >= 4 else { return }
        if onSubmit(pin) {
            pin = ""
        } else {
            withAnimation { error = true }
            pin = ""
        }
    }
}

/// Horizontal shake for a wrong PIN.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size _: CGSize) -> ProjectionTransform {
        let dx = sin(animatableData * .pi * 4) * 8
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
