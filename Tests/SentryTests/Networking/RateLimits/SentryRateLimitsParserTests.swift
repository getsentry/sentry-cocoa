@testable import Sentry
import SentryTestUtils
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
            SentryDataCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("50:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    /**
     * Relay can add reason codes to the rate limit response, see https://github.com/getsentry/relay/pull/850
     * This test makes sure we just ignore the reason code.
     *
     */
    func testIgnoreReasonCode() {
        let expected = [
            SentryDataCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("50:transaction:key:reason")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneQuotaTwoCategories() {
        let retryAfter = CurrentDate.date().addingTimeInterval(50)
        let expected = [
            SentryDataCategory.transaction.asNSNumber: retryAfter,
            SentryDataCategory.error.asNSNumber: retryAfter
        ]
        
        let actual = sut.parse("50:transaction;error:key")
        
        XCTAssertEqual(expected, actual)
    }

    func testTwoQuotasMultipleCategories() {
        let retryAfter2700 = CurrentDate.date().addingTimeInterval(2_700)
        let expected = [
            SentryDataCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50),
            SentryDataCategory.error.asNSNumber: retryAfter2700,
            SentryDataCategory.default.asNSNumber: retryAfter2700,
            SentryDataCategory.attachment.asNSNumber: retryAfter2700
        ]
        
        let actual = sut.parse("50:transaction:key, 2700:error;default;attachment:organization")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testKeepMaximumRateLimit() {
        let expected = [
            SentryDataCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("3:transaction:key,50:transaction:key,5:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testInvalidRetryAfter() {
        let expected = [SentryDataCategory.default.asNSNumber: CurrentDate.date().addingTimeInterval(1)]
        
        let actual = sut.parse("A1:transaction:key, 1:default:organization, -20:B:org, 0:event:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testAllCategories() {
        let expected = [SentryDataCategory.all.asNSNumber: CurrentDate.date().addingTimeInterval(1_000)]
        
        let actual = sut.parse("1000::organization ")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneUnknownAndOneKnownCategory() {
        let expected = [SentryDataCategory.error.asNSNumber: CurrentDate.date().addingTimeInterval(2)]
        
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
            SentryDataCategory.default.asNSNumber: date,
            SentryDataCategory.error.asNSNumber: date,
            SentryDataCategory.session.asNSNumber: date,
            SentryDataCategory.transaction.asNSNumber: date,
            SentryDataCategory.attachment.asNSNumber: date,
            SentryDataCategory.profile.asNSNumber: date,
            SentryDataCategory.all.asNSNumber: date
        ]
        
        let actual = sut.parse("1:default;foobar;error;session;transaction;attachment;profile:organization,1::key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testWhitespacesSpacesAreRemoved() {
        let retryAfter10 = CurrentDate.date().addingTimeInterval(10)
        let expected = [SentryDataCategory.all.asNSNumber: CurrentDate.date().addingTimeInterval(67),
                        SentryDataCategory.transaction.asNSNumber: retryAfter10,
                        SentryDataCategory.error.asNSNumber: retryAfter10
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
            SentryDataCategory.transaction.asNSNumber: CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("A9813Hell,50:transaction:key,123Garbage")
        
        XCTAssertEqual(expected, actual)
    }
}

extension SentryDataCategory {
    var asNSNumber: NSNumber {
        return self.rawValue as NSNumber
    }
}
