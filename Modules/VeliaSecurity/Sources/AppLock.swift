import Foundation

/// Biometric/PIN app-lock + discretion. Implemented in Phase 1 (LAContext, switcher blur, instant lock).
public protocol AppLocking: Sendable {
    func lock()
    func unlock() async throws -> Bool
    var isLocked: Bool { get }
}
