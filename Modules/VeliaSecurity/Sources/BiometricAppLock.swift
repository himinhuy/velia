import Foundation
import LocalAuthentication

// ⚠️ Phase 1 implementation target (requires iOS app build; not compiled by VeliaCore SwiftPM).
// Implements the discretion/app-lock story. Architecture: docs/architecture.md §6.
// App-switcher blur + neutral icon live in the app/Features layer (UIScene lifecycle); the lock
// state machine and biometric evaluation live here.

@MainActor
public final class BiometricAppLock: AppLocking {
    public private(set) var isLocked: Bool = true
    private let reason: String
    private let policy: LAPolicy

    /// `.deviceOwnerAuthentication` allows biometric **with passcode fallback** (recommended).
    public init(
        reason: String = "Mở khóa Velia", // "Unlock Velia"
        policy: LAPolicy = .deviceOwnerAuthentication
    ) {
        self.reason = reason
        self.policy = policy
    }

    public func lock() {
        isLocked = true
    }

    /// Evaluates biometrics/passcode and returns an authenticated context the key provider can use.
    @discardableResult
    public func unlock() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Dùng mật mã" // "Use passcode"

        var authError: NSError?
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            throw authError ?? AppLockError.unavailable
        }
        let ok = try await context.evaluatePolicy(policy, localizedReason: reason)
        isLocked = !ok
        return ok
    }
}

public enum AppLockError: Error { case unavailable }
