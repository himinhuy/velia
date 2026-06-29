import HealthKit
import Observation

/// Reads fertility-relevant signals from Apple Health (on-device). Used to import basal body
/// temperature into conceive-mode logging; heart rate / sleep are authorized for future use.
@MainActor
@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    private(set) var authorized = false

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.basalBodyTemperature),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis)
        ]
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorized = true
            return true
        } catch {
            return false
        }
    }

    /// Most recent basal body temperature (°C) recorded on the given day, if any.
    func basalBodyTemperature(on day: Date) async -> Double? {
        guard isAvailable else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let type = HKQuantityType(.basalBodyTemperature)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, _ in
                let celsius = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .degreeCelsius())
                continuation.resume(returning: celsius)
            }
            store.execute(query)
        }
    }
}
