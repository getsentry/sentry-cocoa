import XCTest

class SentryHttpStatusCodeRangeTests: XCTestCase {
    
    func testWithinRange() {
        let range = HttpStatusCodeRange(min: 500, max: 599)
        
        XCTAssertTrue(range.is(inRange: 550))
    }
    
    func testMinWithinRange() {
        let range = HttpStatusCodeRange(min: 500, max: 599)
        
        XCTAssertTrue(range.is(inRange: 500))
    }
    
    func testLowerMinNotWithinRange() {
        let range = HttpStatusCodeRange(min: 500, max: 599)
        
        XCTAssertFalse(range.is(inRange: 499))
    }
    
    func testMaxWithinRange() {
        let range = HttpStatusCodeRange(min: 500, max: 599)
        
        XCTAssertTrue(range.is(inRange: 599))
    }
    
    func testHigherMaxNotWithinRange() {
        let range = HttpStatusCodeRange(min: 500, max: 599)
        
        XCTAssertFalse(range.is(inRange: 600))
    }
    
    func testStatusCodeWithinRange() {
        let range = HttpStatusCodeRange(statusCode: 500)
        
        XCTAssertTrue(range.is(inRange: 500))
    }
    
    func testStatusCodeNotWithinRange() {
        let range = HttpStatusCodeRange(statusCode: 500)
        
        XCTAssertFalse(range.is(inRange: 200))
    }
}
