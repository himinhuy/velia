import Foundation
import Observation

/// Subscription + free-trial state. Device-global (not per profile).
///
/// **The purchase is simulated locally** — `subscribe()` is the single integration point to swap for
/// StoreKit 2 (an auto-renewable product in App Store Connect + a paid Developer account). Trial
/// timing, gating, status and cancellation are all real. State is a non-PHI preference in UserDefaults.
@MainActor
@Observable
public final class SubscriptionManager {
    public enum Status: Equatable {
        case trial(daysLeft: Int)
        case premium(renewal: Date)
        case expired
    }

    public static let trialDays = 7
    public static let priceString = "$3"

    private enum Keys {
        static let trialStart = "velia.sub.trialStart"
        static let subscribed = "velia.sub.active"
        static let renewal = "velia.sub.renewal"
    }

    private let defaults: UserDefaults
    private var trialStart: Date {
        didSet { defaults.set(trialStart.timeIntervalSince1970, forKey: Keys.trialStart) }
    }
    public private(set) var isSubscribed: Bool {
        didSet { defaults.set(isSubscribed, forKey: Keys.subscribed) }
    }
    public private(set) var renewalDate: Date? {
        didSet { defaults.set(renewalDate?.timeIntervalSince1970 ?? 0, forKey: Keys.renewal) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Trial begins on first launch.
        let saved = defaults.double(forKey: Keys.trialStart)
        if saved > 0 {
            trialStart = Date(timeIntervalSince1970: saved)
        } else {
            let now = Date()
            trialStart = now
            defaults.set(now.timeIntervalSince1970, forKey: Keys.trialStart)
        }
        isSubscribed = defaults.bool(forKey: Keys.subscribed)
        let r = defaults.double(forKey: Keys.renewal)
        renewalDate = r > 0 ? Date(timeIntervalSince1970: r) : nil
    }

    // MARK: Derived

    public var trialEnd: Date {
        Calendar.current.date(byAdding: .day, value: Self.trialDays, to: trialStart) ?? trialStart
    }

    public var trialDaysLeft: Int {
        max(0, Int(ceil(trialEnd.timeIntervalSinceNow / 86_400)))
    }

    public var isTrialActive: Bool { !isSubscribed && Date() < trialEnd }
    public var hasAccess: Bool { isSubscribed || isTrialActive }
    public var needsPaywall: Bool { !hasAccess }

    public var status: Status {
        if isSubscribed { return .premium(renewal: renewalDate ?? oneYearOut()) }
        return isTrialActive ? .trial(daysLeft: trialDaysLeft) : .expired
    }

    // MARK: Actions

    /// Simulated purchase. Swap this body for a StoreKit 2 `Product.purchase()` flow.
    public func subscribe() {
        isSubscribed = true
        renewalDate = oneYearOut()
    }

    /// Cancel — immediate in this local model (real StoreKit cancellation is managed by the system).
    public func cancel() {
        isSubscribed = false
        renewalDate = nil
    }

    private func oneYearOut() -> Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    // MARK: Testing / demo helpers

    /// Force the trial to look expired (so the paywall gate can be demoed without waiting 7 days).
    public func expireTrialForTesting() {
        trialStart = Calendar.current.date(byAdding: .day, value: -(Self.trialDays + 1), to: Date()) ?? Date()
    }

    /// Restart a fresh 7-day trial (clears any subscription).
    public func resetTrialForTesting() {
        trialStart = Date()
        isSubscribed = false
        renewalDate = nil
    }
}
