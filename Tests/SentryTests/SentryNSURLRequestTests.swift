@testable import Sentry
import SentryTestUtils
import XCTest

class SentryNSURLRequestTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNSURLRequestTests")
    private static func dsn() throws -> SentryDsn {
        try TestConstants.dsn(username: "SentryNSURLRequestTests")
    }
    
    func testRequestWithEnvelopeEndpoint() throws {
        let request = try SentryNSURLRequest(envelopeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        let string = try XCTUnwrap(request.url?.absoluteString as? NSString)
        XCTAssert(string.hasSuffix("/envelope/"))
    }
    
    func testRequestWithStoreEndpoint() throws {
        let request = try! SentryNSURLRequest(storeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        let string = try XCTUnwrap(request.url?.absoluteString as? NSString)
        XCTAssert(string.hasSuffix("/store/"))
    }
    
    func testRequestWithEnvelopeEndpoint_hasUserAgentWithSdkNameAndVersion() {
        let request = try! SentryNSURLRequest(envelopeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        XCTAssertEqual(request.allHTTPHeaderFields?["User-Agent"], "\(SentryMeta.sdkName)/\(SentryMeta.versionString)")
    }
    
    func testRequestWithStoreEndpoint_hasUserAgentWithSdkNameAndVersion() {
        let request = try! SentryNSURLRequest(storeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        XCTAssertEqual(request.allHTTPHeaderFields?["User-Agent"], "\(SentryMeta.sdkName)/\(SentryMeta.versionString)")
    }
}
