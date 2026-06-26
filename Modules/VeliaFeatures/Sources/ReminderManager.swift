import Foundation
import Observation
import UserNotifications

/// Opt-in local reminders (PRD §local reminders). Everything is scheduled on-device via
/// `UNUserNotificationCenter` — no push server, no network (invariant #1). Settings are UI
/// preferences (non-PHI) in UserDefaults; notification *content* is only ever shown to the user.
@MainActor
@Observable
public final class ReminderManager {
    // Stable identifiers so rescheduling replaces, not duplicates.
    private static let periodID = "velia.reminder.period"
    private static let fertileID = "velia.reminder.fertile"
    private static let logNudgeID = "velia.reminder.lognudge"

    private enum Keys {
        static let period = "velia.rem.period"
        static let lead = "velia.rem.lead"
        static let nudge = "velia.rem.nudge"
        static let nudgeHour = "velia.rem.nudgeHour"
        static let fertile = "velia.rem.fertile"
    }

    public var periodReminderEnabled: Bool {
        didSet { ud.set(periodReminderEnabled, forKey: Keys.period) }
    }

    public var periodLeadDays: Int {
        didSet { ud.set(periodLeadDays, forKey: Keys.lead) }
    }

    public var logNudgeEnabled: Bool {
        didSet { ud.set(logNudgeEnabled, forKey: Keys.nudge) }
    }

    public var logNudgeHour: Int {
        didSet { ud.set(logNudgeHour, forKey: Keys.nudgeHour) }
    }

    public var fertileReminderEnabled: Bool {
        didSet { ud.set(fertileReminderEnabled, forKey: Keys.fertile) }
    }

    private let ud = UserDefaults.standard
    /// Lazy + observation-ignored: UNUserNotificationCenter.current() requires an app bundle (crashes
    /// in the test host), so it's only created when reminders actually run, never on construction.
    @ObservationIgnored private lazy var center = UNUserNotificationCenter.current()

    public init() {
        periodReminderEnabled = ud.bool(forKey: Keys.period)
        periodLeadDays = ud.object(forKey: Keys.lead) as? Int ?? 2
        logNudgeEnabled = ud.bool(forKey: Keys.nudge)
        logNudgeHour = ud.object(forKey: Keys.nudgeHour) as? Int ?? 20
        fertileReminderEnabled = ud.bool(forKey: Keys.fertile)
    }

    public var anyEnabled: Bool {
        periodReminderEnabled || logNudgeEnabled || fertileReminderEnabled
    }

    /// Request permission (if any reminder is on) and (re)schedule from the active profile's data.
    public func apply(store: CycleStore) async {
        center.removePendingNotificationRequests(withIdentifiers:
            [Self.periodID, Self.fertileID, Self.logNudgeID])

        guard anyEnabled else { return }
        guard await ensureAuthorized() else { return }

        let cal = Calendar.current
        if periodReminderEnabled, store.mode.predictsCycle, let p = store.prediction {
            let fireDay = cal.date(byAdding: .day, value: -periodLeadDays, to: p.nextPeriod.start)
            if let fireDay, fireDay > Date() {
                let n = max(periodLeadDays, 0)
                let body = n == 0
                    ? L2("Kỳ kinh có thể bắt đầu hôm nay.", "Your period may start today.")
                    : L2("Kỳ kinh dự kiến trong \(n) ngày.", "Your period is expected in \(n) days.")
                schedule(Self.periodID, on: at9am(fireDay, cal), body: body)
            }
        }

        if fertileReminderEnabled, store.mode == .conceive, let ov = store.prediction?.ovulation,
           ov.start > Date()
        {
            schedule(
                Self.fertileID,
                on: at9am(ov.start, cal),
                body: L2("Cửa sổ dễ thụ thai sắp bắt đầu.", "Your fertile window is starting soon.")
            )
        }

        if logNudgeEnabled {
            var dc = DateComponents()
            dc.hour = logNudgeHour
            scheduleRepeating(
                Self.logNudgeID,
                components: dc,
                body: L2("Đừng quên ghi nhật ký hôm nay.", "Don't forget to log today.")
            )
        }
    }

    // MARK: Scheduling helpers

    private func at9am(_ date: Date, _ cal: Calendar) -> DateComponents {
        var dc = cal.dateComponents([.year, .month, .day], from: date)
        dc.hour = 9
        return dc
    }

    private func schedule(_ id: String, on components: DateComponents, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Velia"
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleRepeating(_ id: String, components: DateComponents, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Velia"
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func ensureAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}
