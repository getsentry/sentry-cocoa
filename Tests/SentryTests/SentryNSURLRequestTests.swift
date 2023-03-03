@testable import Sentry
import SentryTestUtils
import XCTest

class SentryNSURLRequestTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNSURLRequestTests")
    private static func dsn() throws -> SentryDsn {
        try TestConstants.dsn(username: "SentryNSURLRequestTests")
    }
    
    func testRequestWithEnvelopeEndpoint() {
        let request = try! SentryNSURLRequest(envelopeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("/envelope/"))
    }
    func testRequestWithStoreEndpoint() {
        let request = try! SentryNSURLRequest(storeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("/store/"))
    }
}
