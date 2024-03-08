import Nimble
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
        expect(request.url!.absoluteString).to(endWith("/envelope/"))
    }
    
    func testRequestWithStoreEndpoint() {
        let request = try! SentryNSURLRequest(storeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        expect(request.url!.absoluteString).to(endWith("/store/"))
    }
    
    func testRequestWithEnvelopeEndpoint_hasUserAgentWithSdkNameAndVersion() {
        let request = try! SentryNSURLRequest(envelopeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        expect(request.allHTTPHeaderFields?["User-Agent"]) == "\(SentryMeta.sdkName)/\(SentryMeta.versionString)"
    }
    
    func testRequestWithStoreEndpoint_hasUserAgentWithSdkNameAndVersion() {
        let request = try! SentryNSURLRequest(storeRequestWith: SentryNSURLRequestTests.dsn(), andData: Data())
        expect(request.allHTTPHeaderFields?["User-Agent"]) == "\(SentryMeta.sdkName)/\(SentryMeta.versionString)"
    }
}
