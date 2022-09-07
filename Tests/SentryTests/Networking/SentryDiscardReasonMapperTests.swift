import Foundation
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    func testMapReasonToName() {
        XCTAssertEqual(kSentryDiscardReasonNameBeforeSend, nameForSentryDiscardReason(.beforeSend))
        XCTAssertEqual(kSentryDiscardReasonNameEventProcessor, nameForSentryDiscardReason(.eventProcessor))
        XCTAssertEqual(kSentryDiscardReasonNameSampleRate, nameForSentryDiscardReason(.sampleRate))
        XCTAssertEqual(kSentryDiscardReasonNameNetworkError, nameForSentryDiscardReason(.networkError))
        XCTAssertEqual(kSentryDiscardReasonNameQueueOverflow, nameForSentryDiscardReason(.queueOverflow))
        XCTAssertEqual(kSentryDiscardReasonNameCacheOverflow, nameForSentryDiscardReason(.cacheOverflow))
        XCTAssertEqual(kSentryDiscardReasonNameRateLimitBackoff, nameForSentryDiscardReason(.rateLimitBackoff))
    }
}
