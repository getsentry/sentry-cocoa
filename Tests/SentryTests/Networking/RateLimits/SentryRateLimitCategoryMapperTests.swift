import XCTest
@testable import Sentry

class SentryRateLimitCategoryMapperTests: XCTestCase {
    
    private let categoryError = "error"

    func testAnyEventType() {
        let actual = RateLimitCategoryMapper.mapEventType(toCategory: "any eventtype")
        
        XCTAssertEqual(categoryError, actual)
    }
    
    func testEventItemType() {
        let actual = RateLimitCategoryMapper.mapEventType(toCategory: "event")
        
        XCTAssertEqual(categoryError, actual)
    }
    

    func testEnvelopeItemTypeEvent() {
        let actual = RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: "event")
        
        XCTAssertEqual(categoryError, actual)
    }
    
    func testEnvelopeItemTypeSession() {
        let actual = RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: "session")
        
        XCTAssertEqual("session", actual)
    }
    
    func testAnyEnvelopeItemType() {
        let actual = RateLimitCategoryMapper.mapEnvelopeItemType(toCategory: "any envelope item type")
        
        XCTAssertEqual("any envelope item type", actual)
    }
}
