#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryProcessInfoTests: XCTestCase {

    func testIsiOSAppOnVisionOS() throws {
        // -- Arrange --
        let processInfo = ProcessInfo.processInfo

        // -- Act --
        let result = processInfo.isiOSAppOnVisionOS

        // -- Assert --
        // This test only asserts that the property exists, as we can not adapt the process info in tests
        // and a test running on visionOS is also not an iOS app.
        //
        // We asserted this manually by running iOS-Swift on visionOS, then exploring the data in `lldb`
        XCTAssertFalse(result, "isiOSAppOnVisionOS should be false when not running on visionOS")
    }
}
