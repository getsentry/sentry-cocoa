import XCTest
@testable import Sentry

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
    
    private func mapEnvelopeItemType(itemType: String) -> SentryRateLimitCategory {
        return RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: itemType)
    }
    
    private func mapEventType(eventType: String) -> SentryRateLimitCategory {
        return RateLimitCategoryMapper.mapEventType(toCategory: eventType)
    }
}
