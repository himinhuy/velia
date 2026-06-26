import XCTest
@testable import VeliaDesignSystem

final class ThemeTests: XCTestCase {
    func testTokens() {
        XCTAssertGreaterThan(Theme.cornerRadius, 0)
    }
}
