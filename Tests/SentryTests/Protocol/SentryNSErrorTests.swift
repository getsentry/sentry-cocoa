import XCTest

class SentryNSErrorTests: XCTestCase {

    func testSerialize() {
        let error = SentryNSError(domain: "domain", code: 10)
    
        let actual = error.serialize()
        
        XCTAssertEqual(error.domain, actual["domain"] as? String)
        XCTAssertEqual(error.code, actual["code"] as? Int)
    }

}
