@testable import Sentry
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
    }
}
