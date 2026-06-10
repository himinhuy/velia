import Foundation
import VeliaCore

/// Reads temperature/HR/sleep from HealthKit to enrich fertility signals (Phase 3). Read-only.
public protocol HealthReading: Sendable {
    func requestAuthorization() async throws -> Bool
    func latestWristTemperature() async throws -> Double?
}
