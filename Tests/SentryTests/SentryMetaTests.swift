import Sentry
import XCTest

class SentryMetaTest: XCTestCase {
    func testChangeVersion() {
        SentryMeta.versionString = "0.0.1"
        XCTAssertEqual(SentryMeta.versionString, "0.0.1")
    }

    func testChangeName() {
        SentryMeta.sdkName = "test"
        XCTAssertEqual(SentryMeta.sdkName, "test")
    }
}
