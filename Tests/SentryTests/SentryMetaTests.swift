import Sentry
import XCTest

// swiftlint:disable file_length
// We are aware that the client has a lot of logic and we should maybe
// move some of it to other classes.
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
