@testable import Sentry
import XCTest

class SentryRateLimitsParserTests: XCTestCase {
    
    private var sut: RateLimitParser!
    
    override func setUp() {
        super.setUp()
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        sut = RateLimitParser()
    }
    
    func testOneQuotaOneCategory() {
        let expected = [
            SentryRateLimitCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("50:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneQuotaTwoCategories() {
        let retryAfter = CurrentDate.date().addingTimeInterval(50)
        let expected = [
            SentryRateLimitCategory.transaction.asNSNumber: retryAfter,
            SentryRateLimitCategory.error.asNSNumber: retryAfter
        ]
        
        let actual = sut.parse("50:transaction;error:key")
        
        XCTAssertEqual(expected, actual)
    }

    func testTwoQuotasMultipleCategories() {
        let retryAfter2700 = CurrentDate.date().addingTimeInterval(2_700)
        let expected = [
            SentryRateLimitCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50),
            SentryRateLimitCategory.error.asNSNumber: retryAfter2700,
            SentryRateLimitCategory.default.asNSNumber: retryAfter2700,
            SentryRateLimitCategory.attachment.asNSNumber: retryAfter2700
        ]
        
        let actual = sut.parse("50:transaction:key, 2700:error;default;attachment:organization")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testKeepMaximumRateLimit() {
        let expected = [
            SentryRateLimitCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("3:transaction:key,50:transaction:key,5:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testInvalidRetryAfter() {
        let expected = [SentryRateLimitCategory.default.asNSNumber: CurrentDate.date().addingTimeInterval(1)]
        
        let actual = sut.parse("A1:transaction:key, 1:default:organization, -20:B:org, 0:event:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testAllCategories() {
        let expected = [SentryRateLimitCategory.all.asNSNumber: CurrentDate.date().addingTimeInterval(1_000)]
        
        let actual = sut.parse("1000::organization ")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneUnknownAndOneKnownCategory() {
        let expected = [SentryRateLimitCategory.error.asNSNumber: CurrentDate.date().addingTimeInterval(2)]
        
        let actual = sut.parse("2:foobar;error:organization")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOnlyUnknownCategories() {
        XCTAssertEqual([:], sut.parse("2:foobar:organization"))
        XCTAssertEqual([:], sut.parse("2:foobar;foo;bar:organization"))
    }
    
    func testAllKnownCategories() {
        let date = CurrentDate.date().addingTimeInterval(1)
        let expected = [
            SentryRateLimitCategory.default.asNSNumber: date,
            SentryRateLimitCategory.error.asNSNumber: date,
            SentryRateLimitCategory.session.asNSNumber: date,
            SentryRateLimitCategory.transaction.asNSNumber: date,
            SentryRateLimitCategory.attachment.asNSNumber: date,
            SentryRateLimitCategory.all.asNSNumber: date
        ]
        
        let actual = sut.parse("1:default;foobar;error;session;transaction;attachment:organization,1::key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testWhitespacesSpacesAreRemoved() {
        let retryAfter10 = CurrentDate.date().addingTimeInterval(10)
        let expected = [SentryRateLimitCategory.all.asNSNumber: CurrentDate.date().addingTimeInterval(67),
                        SentryRateLimitCategory.transaction.asNSNumber: retryAfter10,
                        SentryRateLimitCategory.error.asNSNumber: retryAfter10
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
            SentryRateLimitCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("A9813Hell,50:transaction:key,123Garbage")
        
        XCTAssertEqual(expected, actual)
    }
}

extension SentryRateLimitCategory {
    var asNSNumber: NSNumber {
        return self.rawValue as NSNumber
    }
}
