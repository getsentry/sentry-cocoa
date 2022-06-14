import Foundation
import Sentry
import XCTest

class SentryBaggageTests: XCTestCase {
    
    func test_baggageToHeader() {
        let header = SentryBaggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: "teste", transaction: "some transaction", userId: "user", userSegment: "test user").toHTTPHeader()
        
        XCTAssertEqual(header, "sentry-environment=teste,sentry-publickey=publicKey,sentry-release=release%20name,sentry-traceid=00000000000000000000000000000000,sentry-transaction=some%20transaction,sentry-userid=user,sentry-usersegment=test%20user")
    }
    
    func test_baggageToHeader_onlyTrace_ignoreNils() {
        let header = SentryBaggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil, transaction: nil, userId: nil, userSegment: nil).toHTTPHeader()
        
        XCTAssertEqual(header, "sentry-publickey=publicKey,sentry-traceid=00000000000000000000000000000000")
    }
    
}
