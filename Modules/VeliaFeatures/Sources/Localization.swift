import Foundation
import VeliaCore

/// Vietnamese-first display strings and formatters. The MVP ships VN as the default language
/// (PRD §IA); proper string-catalog localization arrives with the content phase. Centralised here
/// so screens never hardcode user-facing copy.
enum L {
    // Tabs
    static let today = "Hôm nay"
    static let calendar = "Lịch"
    static let log = "Nhật ký"

    // App
    static let appName = "Velia"
    static let tagline = "Dự đoán chu kỳ chính xác — riêng tư, của riêng bạn."
    static let privacyFootnote = "Dự đoán trên máy · không tài khoản · không mạng"

    static func phase(_ p: CyclePhase) -> String {
        switch p {
        case .menstrual: return "Hành kinh"
        case .follicular: return "Giai đoạn nang trứng"
        case .ovulatory: return "Rụng trứng"
        case .luteal: return "Giai đoạn hoàng thể"
        case .unknown: return "—"
        }
    }

    static func confidence(_ c: ConfidenceLevel) -> String {
        switch c {
        case .high: return "Độ tin cậy cao"
        case .moderate: return "Độ tin cậy trung bình"
        case .low: return "Độ tin cậy thấp"
        }
    }

    static func segment(_ s: Segment) -> String {
        switch s {
        case .typical: return "Đều / điển hình"
        case .pcos: return "PCOS (buồng trứng đa nang)"
        case .perimenopause: return "Tiền mãn kinh"
        case .postpartum: return "Sau sinh"
        case .unknown: return "Tôi không chắc"
        }
    }

    static func flow(_ f: FlowIntensity) -> String {
        switch f {
        case .spotting: return "Lấm tấm"
        case .light: return "Nhẹ"
        case .medium: return "Vừa"
        case .heavy: return "Nhiều"
        }
    }
}

enum Fmt {
    /// "12 thg 6" style short date.
    static let dayMonth: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.setLocalizedDateFormatFromTemplate("d MMM")
        return df
    }()

    static func range(_ interval: DateInterval) -> String {
        "\(dayMonth.string(from: interval.start)) – \(dayMonth.string(from: interval.end))"
    }

    /// Width of a prediction window in whole days (the "honesty" signal).
    static func widthDays(_ interval: DateInterval) -> Int {
        Int((interval.duration / 86_400).rounded())
    }
}
