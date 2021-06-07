import XCTest

class SentryDependenciesTests: XCTestCase {

    func testProperties() {
        test { SentryDependencies.currentDateProvider }
        test { SentryDependencies.crashAdapter }
        test { SentryDependencies.dispatchQueue }
    }
    
    private func test(property: () -> AnyObject) {
        let object = property()
        XCTAssertNotNil(object)
        XCTAssertTrue(object === property())
    }
}
