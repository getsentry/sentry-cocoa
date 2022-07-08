import Foundation
import Sentry
import XCTest

class SentryBaggageTests: XCTestCase {
    
    func test_baggageToHeader() {
        let header = SentryBaggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: "teste", userSegment: "test user", sampleRate: "0.49").toHTTPHeader()
        
        XCTAssertEqual(header, "sentry-environment=teste,sentry-public_key=publicKey,sentry-release=release%20name,sentry-sample_rate=0.49,sentry-trace_id=00000000000000000000000000000000,sentry-user_segment=test%20user")
    }
    
    func test_baggageToHeader_onlyTrace_ignoreNils() {
        let header = SentryBaggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil, userSegment: nil, sampleRate: nil).toHTTPHeader()
        
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000")
    }
}
