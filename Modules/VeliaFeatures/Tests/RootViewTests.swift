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
        XCTAssertEqual(store.periods.count, 1)
    }

    func testLoggingMoreCyclesIsTracked() {
        let store = CycleStore()
        let cal = Calendar.current
        var day = cal.date(byAdding: .day, value: -90, to: Date())!
        for _ in 0..<3 {
            store.addPeriod(start: day)
            day = cal.date(byAdding: .day, value: 29, to: day)!
        }
        XCTAssertEqual(store.periods.count, 3)
        XCTAssertEqual(store.loggedCycleCount, 2, "3 starts ⇒ 2 complete cycles")
        XCTAssertNotNil(store.prediction)
    }
}
