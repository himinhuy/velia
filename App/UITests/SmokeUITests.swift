import XCTest

/// Critical-flow UI tests (see docs/engineering-practices.md §3.3). Expand per phase.
final class SmokeUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
