@testable import Sentry
import XCTest

class SentryRateLimitCategoryMapperTests: XCTestCase {

    func testEventItemType() {
        XCTAssertEqual(SentryRateLimitCategory.error, mapEventType(eventType: "event"))
        XCTAssertEqual(SentryRateLimitCategory.error, mapEventType(eventType: "any eventtype"))
    }

    func testEnvelopeItemType() {
        XCTAssertEqual(SentryRateLimitCategory.error, mapEnvelopeItemType(itemType: "event"))
        XCTAssertEqual(SentryRateLimitCategory.session, mapEnvelopeItemType(itemType: "session"))
        XCTAssertEqual(SentryRateLimitCategory.transaction, mapEnvelopeItemType(itemType: "transaction"))
        XCTAssertEqual(SentryRateLimitCategory.attachment, mapEnvelopeItemType(itemType: "attachment"))
        XCTAssertEqual(SentryRateLimitCategory.default, mapEnvelopeItemType(itemType: "unkown item type"))
    }

    func testMapIntegerToCategory() {
        XCTAssertEqual(SentryRateLimitCategory.all, RateLimitCategoryMapper.mapInteger(toCategory: 0))
        XCTAssertEqual(SentryRateLimitCategory.default, RateLimitCategoryMapper.mapInteger(toCategory: 1))
        XCTAssertEqual(SentryRateLimitCategory.error, RateLimitCategoryMapper.mapInteger(toCategory: 2))
        XCTAssertEqual(SentryRateLimitCategory.session, RateLimitCategoryMapper.mapInteger(toCategory: 3))
        XCTAssertEqual(SentryRateLimitCategory.transaction, RateLimitCategoryMapper.mapInteger(toCategory: 4))
        XCTAssertEqual(SentryRateLimitCategory.attachment, RateLimitCategoryMapper.mapInteger(toCategory: 5))
        XCTAssertEqual(SentryRateLimitCategory.unknown, RateLimitCategoryMapper.mapInteger(toCategory: 6))
        XCTAssertEqual(SentryRateLimitCategory.unknown, RateLimitCategoryMapper.mapInteger(toCategory: 7))
    }

    private func mapEnvelopeItemType(itemType: String) -> SentryRateLimitCategory {
        return RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: itemType)
    }

    private func mapEventType(eventType: String) -> SentryRateLimitCategory {
        return RateLimitCategoryMapper.mapEventType(toCategory: eventType)
    }
}
