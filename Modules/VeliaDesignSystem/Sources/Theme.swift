import SwiftUI

/// Warm, non-clinical visual language. Tokens live here so screens never hardcode color/spacing.
/// Palette goal (PRD): discreet, calm, *not* clinical pink-medical — a warm rose/clay register.
public enum Theme {
    // MARK: Layout

    public static let cornerRadius: CGFloat = 16
    public static let spacing: CGFloat = 12
    public static let spacingLarge: CGFloat = 20
    public static let spacingSmall: CGFloat = 6

    // MARK: Color tokens (adapt to light/dark automatically)

    /// Primary brand accent — a warm rose.
    public static let accent = Color(red: 0.79, green: 0.36, blue: 0.42)
    /// Softer accent for fills/period markers.
    public static let accentSoft = Color(red: 0.93, green: 0.74, blue: 0.76)
    /// Predicted-window tint (lighter, "uncertain" feel).
    public static let predicted = Color(red: 0.86, green: 0.80, blue: 0.90)
    /// Fertile-window / ovulation tint — a clear teal-blue (consistent across ring + calendar).
    public static let fertile = Color(red: 0.0, green: 0.58, blue: 0.69)
    /// Follicular phase (after period, before the fertile window) — warm amber.
    public static let follicular = Color(red: 0.88, green: 0.66, blue: 0.34)
    /// Luteal phase (after ovulation, before the next period) — soft lavender.
    public static let luteal = Color(red: 0.60, green: 0.52, blue: 0.80)

    /// Card surface.
    public static let card = Color(.secondarySystemBackground)
    public static let screen = Color(.systemBackground)

    // MARK: Confidence → color

    public static func color(forConfidence raw: String) -> Color {
        switch raw {
        case "high": fertile
        case "moderate": accent
        default: .orange
        }
    }
}

public extension View {
    /// Standard rounded card container used across screens.
    func veliaCard() -> some View {
        padding(Theme.spacingLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}
