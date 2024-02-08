import Foundation
import XCTest

class UrlSanitizedTests: XCTestCase {

    func testNoQueryAndFragment() {
        let detail = UrlSanitized(URL: URL(string: "http://sentry.io")!)
        XCTAssertEqual(detail.sanitizedUrl, "http://sentry.io")
    }

    func testWithQueryAndFragment() {
        let detail = UrlSanitized(URL: URL(string: "http://sentry.io?query=value&query2=value2#fragment")!)
        XCTAssertEqual(detail.sanitizedUrl, "http://sentry.io")
        XCTAssertEqual(detail.query, "query=value&query2=value2")
        XCTAssertEqual(detail.fragment, "fragment")
    }

    func testFilterOutUserPasswordNoQuery() {
        let detail = UrlSanitized(URL: URL(string: "http://User:Password@sentry.io")!)
        XCTAssertEqual(detail.sanitizedUrl, "http://[Filtered]:[Filtered]@sentry.io")
    }

    func testFilterOutUserPasswordWithQuery() {
        let detail = UrlSanitized(URL: URL(string: "http://User:Password@sentry.io?query=valye")!)
        XCTAssertEqual(detail.sanitizedUrl, "http://[Filtered]:[Filtered]@sentry.io")
    }
}
