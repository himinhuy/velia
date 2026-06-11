import LocalAuthentication
import Observation
import SwiftUI

/// App-lock state (PRD "discretion suite"). Gates the app behind Face ID / Touch ID / device
/// passcode. The *enabled* flag is a UI preference (not PHI) stored in UserDefaults; the unlock
/// state is per-session only and never persisted, so the app is always locked on cold launch.
@MainActor
@Observable
public final class LockManager {
    private let enabledKey = "app.velia.lock-enabled"

    /// Whether the lock is turned on. Defaults to on when the device can authenticate.
    public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }
    /// Unlocked for this foreground session. Reset on background / cold launch.
    public private(set) var isUnlocked = false
    /// True while a system auth prompt is on screen (prevents double prompts).
    private var authenticating = false

    public init() {
        let available = LockManager.canAuthenticate()
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            isEnabled = available           // mandatory-by-default when biometrics/passcode exist
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
    }

    /// Whether the app should currently show the lock screen.
    public var isLocked: Bool { isEnabled && !isUnlocked }

    public static func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Face ID label vs. generic, for the unlock button.
    public var biometryLabel: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Mở khóa bằng Face ID"
        case .touchID: return "Mở khóa bằng Touch ID"
        default: return "Mở khóa"
        }
    }

    /// Re-lock (instant lock / on background).
    public func lock() { isUnlocked = false }

    /// Prompt the system for authentication. No-op if disabled, already unlocked, or mid-prompt.
    public func authenticate() async {
        guard isEnabled, !isUnlocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = "Dùng mật mã"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Can't authenticate (no passcode set) → don't trap the user out of their data.
            isUnlocked = true
            return
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                      localizedReason: "Mở khóa Velia")
            isUnlocked = ok
        } catch {
            isUnlocked = false // stay locked on cancel/failure
        }
    }
}
