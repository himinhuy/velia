import UIKit

/// App-icon choice for the discretion suite. iOS can swap the *icon* at runtime via
/// `setAlternateIconName`, but the home-screen *name* is fixed at build time — so a true neutral
/// display name isn't possible without a separate build. We surface the neutral icon only.
enum AppIconOption: String, CaseIterable, Identifiable {
    case primary   // Velia rose ring
    case neutral   // abstract "disguise"

    var id: String { rawValue }

    /// nil = primary icon; otherwise the CFBundleAlternateIcons key.
    var alternateName: String? { self == .neutral ? "Neutral" : nil }

    var label: String {
        switch self {
        case .primary: return "Velia (mặc định)"
        case .neutral: return "Trung tính (kín đáo)"
        }
    }

    @MainActor static var supported: Bool { UIApplication.shared.supportsAlternateIcons }

    @MainActor static var current: AppIconOption {
        UIApplication.shared.alternateIconName == "Neutral" ? .neutral : .primary
    }

    @MainActor static func apply(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != option.alternateName else { return }
        UIApplication.shared.setAlternateIconName(option.alternateName)
    }
}
