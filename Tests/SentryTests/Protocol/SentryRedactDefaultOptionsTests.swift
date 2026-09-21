#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryRedactDefaultOptionsTests: XCTestCase {

    func testDefaultOptions() {
        // -- Act --
        let options = SentryRedactDefaultOptions()

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
        XCTAssertEqual(options.excludedViewClasses.count, 0)
        XCTAssertEqual(options.includedViewClasses.count, 0)
    }
}
