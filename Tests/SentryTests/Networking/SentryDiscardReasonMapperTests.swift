import Foundation
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    func testMapReasonToName() {
        XCTAssertEqual(kSentryDiscardReasonNameBeforeSend, discardReasonName(.beforeSend))
        XCTAssertEqual(kSentryDiscardReasonNameEventProcessor, discardReasonName(.eventProcessor))
        XCTAssertEqual(kSentryDiscardReasonNameSampleRate, discardReasonName(.sampleRate))
        XCTAssertEqual(kSentryDiscardReasonNameNetworkError, discardReasonName(.networkError))
        XCTAssertEqual(kSentryDiscardReasonNameQueueOverflow, discardReasonName(.queueOverflow))
        XCTAssertEqual(kSentryDiscardReasonNameCacheOverflow, discardReasonName(.cacheOverflow))
        XCTAssertEqual(kSentryDiscardReasonNameRateLimitBackoff, discardReasonName(.rateLimitBackoff))
    }
}
