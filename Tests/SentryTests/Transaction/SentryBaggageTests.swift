import _SentryPrivate
import Foundation
import Sentry
import XCTest

class SentryBaggageTests: XCTestCase {
    func test_baggageToHeader_AppendToOriginal() {
        let header = Baggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: "teste", transaction: "transaction", userSegment: "test user", sampleRate: "0.49", sampled: "true", replayId: "some_replay_id").toHTTPHeader(withOriginalBaggage: ["a": "a", "sentry-trace_id": "to-be-overwritten"])

        XCTAssertEqual(header, "a=a,sentry-environment=teste,sentry-public_key=publicKey,sentry-release=release%20name,sentry-replay_id=some_replay_id,sentry-sample_rate=0.49,sentry-sampled=true,sentry-trace_id=00000000000000000000000000000000,sentry-transaction=transaction,sentry-user_segment=test%20user")
    }
    
    func test_baggageToHeader_onlyTrace_ignoreNils() {
        let header = Baggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil, transaction: nil, userSegment: nil, sampleRate: nil, sampled: nil, replayId: nil).toHTTPHeader(withOriginalBaggage: nil)
        
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000")
    }
}
