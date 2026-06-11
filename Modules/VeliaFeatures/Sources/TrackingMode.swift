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
        case .period: return L2("Theo dõi kỳ kinh", "Track my period")
        case .conceive: return L2("Đang muốn có thai", "Try to conceive")
        case .noPeriod: return L2("Theo dõi không kinh nguyệt", "Track without a period")
        case .pregnancy: return L2("Theo dõi thai kỳ", "Follow my pregnancy")
        case .perimenopause: return L2("Theo dõi tiền mãn kinh", "Track perimenopause")
        }
    }

    var subtitle: String {
        switch self {
        case .period: return L2("Ghi lại kỳ kinh và chu kỳ để nhận dự đoán.",
                                "Log your period and cycle to get predictions.")
        case .conceive: return L2("Theo dõi cửa sổ dễ thụ thai và các tín hiệu sinh sản.",
                                  "Track your fertile window and fertility signals.")
        case .noPeriod: return L2("Ghi lại các trải nghiệm lặp lại để nhận thông tin.",
                                  "Log recurring experiences to get insights.")
        case .pregnancy: return L2("Đồng hành cùng thai kỳ với nội dung theo tuần.",
                                   "Follow your pregnancy with weekly content.")
        case .perimenopause: return L2("Hiểu những thay đổi khi cơ thể chuyển sang mãn kinh.",
                                       "Understand changes as your body nears menopause.")
        }
    }
}
