import Foundation
import VeliaCore

/// Centralised display strings. Bilingual via `L2(vi, en)` — Vietnamese-first, English on toggle.
enum L {
    /// Tabs
    static var today: String {
        L2("Hôm nay", "Today")
    }

    static var calendar: String {
        L2("Lịch", "Calendar")
    }

    static var log: String {
        L2("Nhật ký", "Log")
    }

    // App
    static let appName = "Velia"
    static var tagline: String {
        L2(
            "Dự đoán chu kỳ chính xác — riêng tư, của riêng bạn.",
            "Accurate cycle predictions — private, yours alone."
        )
    }

    static var privacyFootnote: String {
        L2(
            "Dự đoán trên máy · không tài khoản · không mạng",
            "On-device prediction · no account · no network"
        )
    }

    static func phase(_ p: CyclePhase) -> String {
        switch p {
        case .menstrual: L2("Hành kinh", "Menstrual")
        case .follicular: L2("Giai đoạn nang trứng", "Follicular phase")
        case .ovulatory: L2("Rụng trứng", "Ovulatory")
        case .luteal: L2("Giai đoạn hoàng thể", "Luteal phase")
        case .unknown: "—"
        }
    }

    static func confidence(_ c: ConfidenceLevel) -> String {
        switch c {
        case .high: L2("Độ tin cậy cao", "High confidence")
        case .moderate: L2("Độ tin cậy trung bình", "Moderate confidence")
        case .low: L2("Độ tin cậy thấp", "Low confidence")
        }
    }

    static func segment(_ s: Segment) -> String {
        switch s {
        case .typical: L2("Đều / điển hình", "Regular / typical")
        case .pcos: L2("PCOS (buồng trứng đa nang)", "PCOS (polycystic ovary syndrome)")
        case .perimenopause: L2("Tiền mãn kinh", "Perimenopause")
        case .postpartum: L2("Sau sinh", "Postpartum")
        case .unknown: L2("Tôi không chắc", "I'm not sure")
        }
    }

    static func flow(_ f: FlowIntensity) -> String {
        switch f {
        case .spotting: L2("Lấm tấm", "Spotting")
        case .light: L2("Nhẹ", "Light")
        case .medium: L2("Vừa", "Medium")
        case .heavy: L2("Nhiều", "Heavy")
        }
    }
}

enum Fmt {
    /// Locale-aware short date ("12 thg 6" / "Jun 12").
    static var dayMonth: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
        df.setLocalizedDateFormatFromTemplate("d MMM")
        return df
    }

    static func range(_ interval: DateInterval) -> String {
        let df = dayMonth
        return "\(df.string(from: interval.start)) – \(df.string(from: interval.end))"
    }

    static func widthDays(_ interval: DateInterval) -> Int {
        Int((interval.duration / 86400).rounded())
    }

    /// Weekday initial (T2…CN / M…S), localised.
    static func weekdayLetter(_ date: Date) -> String {
        let vi = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
        let en = ["S", "M", "T", "W", "T", "F", "S"]
        let idx = Calendar.current.component(.weekday, from: date) - 1
        return AppLanguage.current == .en ? en[idx] : vi[idx]
    }

    static func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df.string(from: date).capitalized
    }
}
