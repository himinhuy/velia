import Foundation

/// The user's tracking intent. A non-destructive UI lens over the same logged data — switching modes
/// never deletes anything. Pregnancy & perimenopause are Tier-2/3 (regulatory-gated per the decision
/// log) and ship locked. "Conceive" is the Tier-1 *fertility-awareness* reframing — emphasis + signal
/// logging only, never conception-optimization or medical advice (architecture §0 invariant #6).
public enum TrackingMode: String, CaseIterable, Sendable, Codable {
    case period
    case conceive
    case noPeriod
    case pregnancy
    case perimenopause

    /// Functional today vs. locked "coming soon".
    public var isFunctional: Bool {
        switch self {
        case .period, .conceive, .noPeriod: return true
        case .pregnancy, .perimenopause: return false
        }
    }

    /// Whether this mode forecasts a cycle (drives whether the engine prediction is shown).
    public var predictsCycle: Bool {
        self == .period || self == .conceive
    }

    var title: String {
        switch self {
        case .period: return "Theo dõi kỳ kinh"
        case .conceive: return "Đang muốn có thai"
        case .noPeriod: return "Theo dõi không kinh nguyệt"
        case .pregnancy: return "Theo dõi thai kỳ"
        case .perimenopause: return "Theo dõi tiền mãn kinh"
        }
    }

    var subtitle: String {
        switch self {
        case .period: return "Ghi lại kỳ kinh và chu kỳ để nhận dự đoán."
        case .conceive: return "Theo dõi cửa sổ dễ thụ thai và các tín hiệu sinh sản."
        case .noPeriod: return "Ghi lại các trải nghiệm lặp lại để nhận thông tin."
        case .pregnancy: return "Đồng hành cùng thai kỳ với nội dung theo tuần."
        case .perimenopause: return "Hiểu những thay đổi khi cơ thể chuyển sang mãn kinh."
        }
    }
}
