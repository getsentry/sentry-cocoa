import Foundation
@testable import Sentry
import XCTest

class StringExtensionsTests: XCTestCase {
    func testSnakeToCamelCase() {
        XCTAssertEqual("name_something".snakeToCamelCase(), "nameSomething")
        XCTAssertEqual("name_something_else".snakeToCamelCase(), "nameSomethingElse")
        XCTAssertEqual("KEEP_CASE".snakeToCamelCase(), "KEEPCASE")
    }
}
