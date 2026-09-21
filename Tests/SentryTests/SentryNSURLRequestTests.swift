#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import SentryTestUtils
import XCTest

class SentryNSURLRequestTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNSURLRequestTests")
    private static func dsn() throws -> SentryDsn {
        try TestConstants.dsn(username: "SentryNSURLRequestTests")
    }
    
    func testRequestWithEnvelopeEndpoint() throws {
        let request = try SentryURLRequestFactory.envelopeRequest(with: SentryNSURLRequestTests.dsn(), data: Data())
        let string = try XCTUnwrap(request.url?.absoluteString as? NSString)
        XCTAssertTrue(string.hasSuffix("/envelope/"))
    }
    
    func testRequestWithEnvelopeEndpoint_hasUserAgentWithSdkNameAndVersion() throws {
        let request = try XCTUnwrap(SentryURLRequestFactory.envelopeRequest(with: SentryNSURLRequestTests.dsn(), data: Data()))
        XCTAssertEqual(request.allHTTPHeaderFields?["User-Agent"], "\(SentryMeta.sdkName)/\(SentryMeta.versionString)")
    }
}
