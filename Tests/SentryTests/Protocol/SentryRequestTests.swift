import XCTest

class SentryRequestTests: XCTestCase {
    func testSerialize() {
        let request = TestData.request
        
        let actual = request.serialize()

        XCTAssertEqual(request.url, actual["url"] as? String)
        XCTAssertEqual(request.queryString, actual["query_string"] as? String)
        XCTAssertEqual(request.fragment, actual["fragment"] as? String)
        XCTAssertEqual(request.cookies, actual["cookies"] as? String)
        XCTAssertEqual(request.method, actual["method"] as? String)
        XCTAssertEqual(request.bodySize, actual["body_size"] as? NSNumber)
        
        XCTAssertEqual(request.headers, actual["headers"] as? Dictionary)
    }
    
    func testNoHeaders() {
        let request = TestData.request
        request.headers = nil
        
        let actual = request.serialize()
        
        XCTAssertNil(actual["headers"])
    }
    
    func testNoBodySize() {
        let request = TestData.request
        request.bodySize = 0
        
        let actual = request.serialize()
        
        XCTAssertNil(actual["body_size"])
    }
}
