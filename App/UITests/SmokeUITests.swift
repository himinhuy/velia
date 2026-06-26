import XCTest

/// Critical-flow UI tests (see docs/engineering-practices.md §3.3). Expand per phase.
@MainActor
final class SmokeUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
