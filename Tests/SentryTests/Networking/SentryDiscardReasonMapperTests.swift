import Foundation
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    
    func testMapStringToCategory() {
        XCTAssertEqual(.beforeSend, SentryDiscardReasonMapper.mapString(toReason: ""))
        XCTAssertEqual(.beforeSend, SentryDiscardReasonMapper.mapString(toReason: "before_send"))
        XCTAssertEqual(.eventProcessor, SentryDiscardReasonMapper.mapString(toReason: "event_processor"))
        XCTAssertEqual(.sampleRate, SentryDiscardReasonMapper.mapString(toReason: "sample_rate"))
        XCTAssertEqual(.networkError, SentryDiscardReasonMapper.mapString(toReason: "network_error"))
        XCTAssertEqual(.queueOverflow, SentryDiscardReasonMapper.mapString(toReason: "queue_overflow"))
        XCTAssertEqual(.cacheOverflow, SentryDiscardReasonMapper.mapString(toReason: "cache_overflow"))
        XCTAssertEqual(.rateLimitBackoff, SentryDiscardReasonMapper.mapString(toReason: "ratelimit_backoff"))
    }
}
