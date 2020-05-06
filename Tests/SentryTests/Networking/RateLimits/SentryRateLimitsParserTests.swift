import XCTest
@testable import Sentry

class SentryRateLimitsParserTests: XCTestCase {
    
    private var sut: RateLimitParser!
    
    override func setUp() {
        super.setUp()
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        sut = RateLimitParser()
    }
    
    func testOneQuotaOneCategory() {
        let expected = [
            SentryRateLimitCategory.transaction.rawValue as NSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("50:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneQuotaTwoCategories() {
        let retryAfter = CurrentDate.date().addingTimeInterval(50)
        let expected = [
            SentryRateLimitCategory.transaction.rawValue as NSNumber: retryAfter,
            SentryRateLimitCategory.error.rawValue as NSNumber: retryAfter
        ]
        
        let actual = sut.parse("50:transaction;error:key")
        
        XCTAssertEqual(expected, actual)
    }

    func testTwoQuotasMultipleCategories() {
        let retryAfter2700 = CurrentDate.date().addingTimeInterval(2700)
        let expected = [
            SentryRateLimitCategory.transaction.rawValue as NSNumber: CurrentDate.date().addingTimeInterval(50),
            SentryRateLimitCategory.error.rawValue as NSNumber: retryAfter2700,
            SentryRateLimitCategory.default.rawValue as NSNumber: retryAfter2700,
            SentryRateLimitCategory.attachment.rawValue as NSNumber: retryAfter2700,
        ]
        
        let actual = sut.parse("50:transaction:key, 2700:error;default;attachment:organization")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testInvalidRetryAfter() {
        let expected = [SentryRateLimitCategory.default.rawValue as NSNumber : CurrentDate.date().addingTimeInterval(1)]
        
        let actual = sut.parse("A1:transaction:key, 1:default:organization, -20:B:org, 0:event:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testAllCategories() {
        let expected = [SentryRateLimitCategory.all.rawValue as NSNumber : CurrentDate.date().addingTimeInterval(1000)]
        
        let actual = sut.parse("1000::organization ")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testAllKnownCategories() {
        let date = CurrentDate.date().addingTimeInterval(1)
        let expected = [
            SentryRateLimitCategory.default.rawValue as NSNumber : date,
            SentryRateLimitCategory.error.rawValue as NSNumber : date,
            SentryRateLimitCategory.session.rawValue as NSNumber : date,
            SentryRateLimitCategory.transaction.rawValue as NSNumber : date,
            SentryRateLimitCategory.attachment.rawValue as NSNumber : date,
            SentryRateLimitCategory.unknown.rawValue as NSNumber : date,
            SentryRateLimitCategory.all.rawValue as NSNumber : date
        ]
        
        
        let actual = sut.parse("1:default;error;session;transaction;attachment;foobar:organization,1::key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testWhitespacesSpacesAreRemoved() {
        let retryAfter10 = CurrentDate.date().addingTimeInterval(10)
        let expected = [SentryRateLimitCategory.all.rawValue as NSNumber : CurrentDate.date().addingTimeInterval(67),
                        SentryRateLimitCategory.transaction.rawValue as NSNumber : retryAfter10,
                        SentryRateLimitCategory.error.rawValue as NSNumber: retryAfter10
        ]
        
        let actual = sut.parse(" 67: :organization ,  10 :transa cti on; error: key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testEmptyString() {
        XCTAssertEqual([:], sut.parse(""))
    }
    
    func testGarbageHeaders() {
        XCTAssertEqual([:], sut.parse("Garb age13$@#"))
        XCTAssertEqual([:], sut.parse(";;;!,  ;"))
        XCTAssertEqual([:], sut.parse("  \n\n  "))
        XCTAssertEqual([:], sut.parse("\n\n"))
    }
    
    func testValidHeaderAndGarbage() {
        let expected = [
            SentryRateLimitCategory.transaction.rawValue as NSNumber : CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("A9813Hell,50:transaction:key,123Garbage")
        
        XCTAssertEqual(expected, actual)
    }
}
