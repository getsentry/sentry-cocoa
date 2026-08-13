@_spi(Private) import Sentry
import XCTest

class SentryDiscardReasonMapperTests: XCTestCase {
    func testMapReasonToName() {
        XCTAssertEqual(SentryDiscardReason.beforeSend.name, SentryDiscardReasonMapper.nameFor(.beforeSend))
        XCTAssertEqual(SentryDiscardReason.eventProcessor.name, SentryDiscardReasonMapper.nameFor(.eventProcessor))
        XCTAssertEqual(SentryDiscardReason.sampleRate.name, SentryDiscardReasonMapper.nameFor(.sampleRate))
        XCTAssertEqual(SentryDiscardReason.networkError.name, SentryDiscardReasonMapper.nameFor(.networkError))
        XCTAssertEqual(SentryDiscardReason.queueOverflow.name, SentryDiscardReasonMapper.nameFor(.queueOverflow))
        XCTAssertEqual(SentryDiscardReason.cacheOverflow.name, SentryDiscardReasonMapper.nameFor(.cacheOverflow))
        XCTAssertEqual(SentryDiscardReason.rateLimitBackoff.name, SentryDiscardReasonMapper.nameFor(.rateLimitBackoff))
        XCTAssertEqual(SentryDiscardReason.insufficientData.name, SentryDiscardReasonMapper.nameFor(.insufficientData))
        XCTAssertEqual(SentryDiscardReason.sendError.name, SentryDiscardReasonMapper.nameFor(.sendError))
    }
}
