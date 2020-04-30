import XCTest
@testable import Sentry

class SentryRateLimitCategoryMapperTests: XCTestCase {
    
    private let categoryError = "error"
    
    func testEventItemType() {
        XCTAssertEqual(categoryError, mapEventType(eventType: "event"))
        XCTAssertEqual(categoryError, mapEventType(eventType: "any eventtype"))
    }
    
    func testEnvelopeItemType() {
        XCTAssertEqual(categoryError, mapEnvelopeItemType(itemType: "event"))
        XCTAssertEqual("session", mapEnvelopeItemType(itemType: "session"))
        XCTAssertEqual("transaction", mapEnvelopeItemType(itemType: "transaction"))
        XCTAssertEqual("default", mapEnvelopeItemType(itemType: "unkown item type"))
    }
    
    private func mapEnvelopeItemType(itemType: String) -> String {
        return RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: itemType)
    }
    
    private func mapEventType(eventType: String) -> String {
        return RateLimitCategoryMapper.mapEventType(toCategory: eventType)
    }
}
