@testable import Sentry
import XCTest

class SentryHttpHeaderCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToDenyList() {
        let options = SentryDataCollection.HttpHeaderCollectionOptions()
        XCTAssertEqual(options.request, .denyList())
        XCTAssertEqual(options.response, .denyList())
    }

    func testInit_withArguments_shouldSetBothDirections() {
        let options = SentryDataCollection.HttpHeaderCollectionOptions(
            request: .allowList(terms: ["authorization"]),
            response: .off
        )
        XCTAssertEqual(options.request, .allowList(terms: ["authorization"]))
        XCTAssertEqual(options.response, .off)
    }
}
