@testable import Sentry
import XCTest

class SentryNSURLRequestTests: XCTestCase {
    
    func testRequestWithEnvelopeEndpoint() {
        let request = try! SentryNSURLRequest(envelopeRequestWith: TestConstants.dsn, andData: Data())
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("/envelope/"))
    }
    func testRequestWithStoreEndpoint() {
        let request = try! SentryNSURLRequest(storeRequestWith: TestConstants.dsn, andData: Data())
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("/store/"))
    }
}
