import XCTest
import VeliaCore
@testable import VeliaFeatures

@MainActor
final class RootViewTests: XCTestCase {
    func testRootViewInstantiates() { _ = RootView() }

    func testStoreSeedsPredictionFromOnboarding() {
        let store = CycleStore()
        XCTAssertNil(store.prediction, "No prediction before any period is known")

        store.completeOnboarding(
            profile: UserProfile(typicalCycleLength: 28, segment: .typical),
            lastPeriodStart: Date()
        )

        XCTAssertTrue(store.hasOnboarded)
        XCTAssertNotNil(store.prediction, "A single seeded period yields a (wide) prediction from the prior")
        XCTAssertEqual(store.periodDays.count, 1)
    }

    /// Contiguous logged days collapse into one run (one period); non-adjacent days form new cycles.
    func testContiguousDaysFormOneRun() {
        let store = CycleStore()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -40, to: Date())!
        for offset in 0..<5 {
            store.setFlow(on: cal.date(byAdding: .day, value: offset, to: start)!, flow: .medium)
        }
        XCTAssertEqual(store.periodDays.count, 5)
        XCTAssertEqual(store.periodRuns().count, 1, "5 consecutive days = one period")
        XCTAssertEqual(store.loggedCycleCount, 0)
    }

    func testCycleCountAndAverageFromRuns() {
        let store = CycleStore()
        let cal = Calendar.current
        var day = cal.date(byAdding: .day, value: -90, to: Date())!
        for _ in 0..<3 {
            store.setFlow(on: day, flow: .medium)        // one-day run
            day = cal.date(byAdding: .day, value: 29, to: day)!
        }
        XCTAssertEqual(store.periodRuns().count, 3)
        XCTAssertEqual(store.loggedCycleCount, 2, "3 runs ⇒ 2 complete cycles")
        XCTAssertEqual(store.averageCycleLength, 29)
        XCTAssertNotNil(store.prediction)
    }

    func testToggleFlowAndSymptom() {
        let store = CycleStore()
        let today = Date()
        store.setFlow(on: today, flow: .heavy)
        XCTAssertEqual(store.flow(on: today), .heavy)
        store.setFlow(on: today, flow: nil)
        XCTAssertFalse(store.isPeriodDay(on: today))

        store.toggleSymptom(TrackCatalog.feelingCategory, "happy", on: today)
        XCTAssertTrue(store.isSymptomSelected(TrackCatalog.feelingCategory, "happy", on: today))
        store.toggleSymptom(TrackCatalog.feelingCategory, "happy", on: today)
        XCTAssertFalse(store.isSymptomSelected(TrackCatalog.feelingCategory, "happy", on: today))
    }

    func testUpdateProfile() {
        let store = CycleStore()
        store.updateProfile(typicalCycleLength: 31, segment: .pcos, birthYear: 1990)
        XCTAssertEqual(store.profile.typicalCycleLength, 31)
        XCTAssertEqual(store.profile.segment, .pcos)
        XCTAssertEqual(store.profile.birthYear, 1990)
    }
}
