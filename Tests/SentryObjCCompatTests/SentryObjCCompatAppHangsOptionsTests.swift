import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatAppHangsOptionsTests: XCTestCase {

    func testEnableV3_defaultsToFalse() {
        let experimental = SentryObjCExperimentalOptions()
        XCTAssertFalse(experimental.appHangs.enableV3)
    }

    func testEnableV3_propagatesWrite() {
        let experimental = SentryObjCExperimentalOptions()
        experimental.appHangs.enableV3 = true
        XCTAssertTrue(experimental.appHangs.enableV3)
        XCTAssertTrue(experimental.wrapped.appHangs.enableV3)
    }

    func testAppHangThreshold_defaultsToTwo() {
        let experimental = SentryObjCExperimentalOptions()
        XCTAssertEqual(experimental.appHangs.threshold, 2.0)
    }

    func testAppHangThreshold_propagatesWrite() {
        let experimental = SentryObjCExperimentalOptions()
        experimental.appHangs.threshold = 5.0
        XCTAssertEqual(experimental.appHangs.threshold, 5.0)
        XCTAssertEqual(experimental.wrapped.appHangs.threshold, 5.0)
    }

    func testOptionsRoundTrip_throughObjCWrapper() {
        let options = SentryObjCOptions()
        options.experimental.appHangs.enableV3 = true
        options.experimental.appHangs.threshold = 3.0

        XCTAssertTrue(options.experimental.appHangs.enableV3)
        XCTAssertEqual(options.experimental.appHangs.threshold, 3.0)
    }
}
