import XCTest
@testable import Sentry

class SentryRateLimitCategoryMapperTests: XCTestCase {

    func testAnyEventType() {
        let actual = RateLimitCategoryMapper.mapEventType(toCategory: "any eventtype")
        
        XCTAssertEqual(SentryRateLimitCategoryError, actual)
    }
    
    func testEventItemType() {
        let actual = RateLimitCategoryMapper.mapEventType(toCategory: SentryEnvelopeItemTypeEvent)
        
        XCTAssertEqual(SentryRateLimitCategoryError, actual)
    }

}
