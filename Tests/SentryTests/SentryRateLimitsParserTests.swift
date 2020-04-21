import XCTest
@testable import Sentry

class SentrysutTests: XCTestCase {
    
    private var sut: RateLimitParser!
    
    override func setUp() {
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        sut = RateLimitParser()
    }
    
    func testOneQuotaOneCategory() {
        let expected = [
            "transaction": CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("50:transaction:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testOneQuotaTwoCategories() {
        let retryAfter = CurrentDate.date().addingTimeInterval(50)
        let expected = [
            "transaction": retryAfter,
            "event": retryAfter
        ]
        
        let actual = sut.parse("50:transaction;event:key")
        
        XCTAssertEqual(expected, actual)
    }

    func testTwoQuotasMultipleCategories() {
        let retryAfter2700 = CurrentDate.date().addingTimeInterval(2700)
        let expected = [
            "transaction": CurrentDate.date().addingTimeInterval(50),
            "event": retryAfter2700,
            "default": retryAfter2700,
            "security": retryAfter2700,
        ]
        
        let actual = sut.parse("50:transaction:key, 2700:default;event;security:organization")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testInvalidRetryAfter() {
        let expected = ["default":CurrentDate.date().addingTimeInterval(1)]
        
        let actual = sut.parse("A1:transaction:key, 1:default:organization, -20:B:org, 0:event:key")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testAllCategories() {
        let expected = ["" : CurrentDate.date().addingTimeInterval(1000)]
        
        let actual = sut.parse("1000::organization ")
        
        XCTAssertEqual(expected, actual)
    }
    
    func testWhitespacesSpacesAreRemoved() {
        let retryAfter10 = CurrentDate.date().addingTimeInterval(10)
        let expected = ["" : CurrentDate.date().addingTimeInterval(67),
                        "transaction": retryAfter10,
                        "event": retryAfter10
        ]
        
        let actual = sut.parse(" 67: :organization ,  10 :transa cti on; event: key")
        
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
            "transaction": CurrentDate.date().addingTimeInterval(50)
        ]
        
        let actual = sut.parse("A9813Hell,50:transaction:key,123Garbage")
        
        XCTAssertEqual(expected, actual)
    }
}
