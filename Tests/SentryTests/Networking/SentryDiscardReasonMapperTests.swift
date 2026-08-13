@_spi(Private) import Sentry
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    func testMapReasonToName() {
        XCTAssertEqual("before_send", SentryDiscardReason.beforeSend.name)
        XCTAssertEqual("event_processor", SentryDiscardReason.eventProcessor.name)
        XCTAssertEqual("sample_rate", SentryDiscardReason.sampleRate.name)
        XCTAssertEqual("network_error", SentryDiscardReason.networkError.name)
        XCTAssertEqual("queue_overflow", SentryDiscardReason.queueOverflow.name)
        XCTAssertEqual("cache_overflow", SentryDiscardReason.cacheOverflow.name)
        XCTAssertEqual("ratelimit_backoff", SentryDiscardReason.rateLimitBackoff.name)
        XCTAssertEqual("insufficient_data", SentryDiscardReason.insufficientData.name)
        XCTAssertEqual("send_error", SentryDiscardReason.sendError.name)
    }
}
