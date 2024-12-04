import XCTest

class SentryMetaTests: XCTestCase {

    func testPackagesAreNotNil() {
        XCTAssertNotNil(SentryMeta.sdkPackages())
    }
}
