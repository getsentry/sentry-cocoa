import Foundation
@testable import SentryTestUtils
import XCTest

class TestContstantTests: XCTestCase {
    func testDsnForTestCase_localTargetClass_shouldUseTypeNameInDSN() {
        // -- Arrange --
        class FooTests: XCTestCase {}

        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: FooTests.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://FooTests:password@app.getsentry.com/12345")
    }

    func testDsnForTestCase_externalFrameworkObjectiveCClass_shouldUseTypeNameInDSN() {
        // -- Arrange --
        class FooTests: XCTestCase {}

        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: NSDecimalNumber.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://NSDecimalNumber:password@app.getsentry.com/12345")
    }

    func testDsnForTestCase_externalFrameworkSwiftClass_shouldUseTypeNameInDSN() {
        // -- Arrange --
        class FooTests: XCTestCase {}

        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: String.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://String:password@app.getsentry.com/12345")
    }
}
