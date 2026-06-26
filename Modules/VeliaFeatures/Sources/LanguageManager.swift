import Observation
import SwiftUI

/// App language. Vietnamese-first (VN-first launch); English available via the in-app toggle.
public enum AppLanguage: String, CaseIterable, Sendable {
    case vi
    case en

    /// Current language, read by the global `L2` helper. Written only on the main actor (by
    /// `LanguageManager`); reads are benign, so `nonisolated(unsafe)` keeps localization callable
    /// from non-isolated provider code (formatters, model builders).
    nonisolated(unsafe) static var current: AppLanguage = .vi

    var label: String {
        self == .vi ? "Tiếng Việt" : "English"
    }

    var localeIdentifier: String {
        self == .vi ? "vi_VN" : "en_US"
    }
}

/// Inline bilingual string: the Vietnamese and English variants live together at the call site,
/// so interpolation works naturally (`L2("Còn \(n) ngày", "\(n) days left")`).
public func L2(_ vi: String, _ en: String) -> String {
    AppLanguage.current == .en ? en : vi
}

/// Holds the selected language (persisted, non-PHI) and keeps `AppLanguage.current` in sync.
@MainActor
@Observable
public final class LanguageManager {
    private let key = "app.velia.language"

    public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: key)
            AppLanguage.current = language
        }
    }

    public init() {
        let saved = UserDefaults.standard.string(forKey: key).flatMap(AppLanguage.init(rawValue:))
        language = saved ?? .vi
        AppLanguage.current = language
    }
}
