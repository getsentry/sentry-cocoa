@_spi(Private) import Sentry
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    func testMapReasonToName() {
        XCTAssertEqual("before_send", SentryDiscardReasonMapper.nameFor(.beforeSend))
        XCTAssertEqual("event_processor", SentryDiscardReasonMapper.nameFor(.eventProcessor))
        XCTAssertEqual("sample_rate", SentryDiscardReasonMapper.nameFor(.sampleRate))
        XCTAssertEqual("network_error", SentryDiscardReasonMapper.nameFor(.networkError))
        XCTAssertEqual("queue_overflow", SentryDiscardReasonMapper.nameFor(.queueOverflow))
        XCTAssertEqual("cache_overflow", SentryDiscardReasonMapper.nameFor(.cacheOverflow))
        XCTAssertEqual("ratelimit_backoff", SentryDiscardReasonMapper.nameFor(.rateLimitBackoff))
        XCTAssertEqual("insufficient_data", SentryDiscardReasonMapper.nameFor(.insufficientData))
        XCTAssertEqual("send_error", SentryDiscardReasonMapper.nameFor(.sendError))
    }
}
