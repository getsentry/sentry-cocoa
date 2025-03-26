@testable import Sentry
import XCTest

class SentryCodableTests: XCTestCase {

    func testDecodeWithEmptyData_ReturnsNil() {
        XCTAssertNil(decodeFromJSONData(jsonData: Data()) as Geo?)
    }
    
    func testDecodeWithGarbageData_ReturnsNil() {
        let data = Data("garbage".utf8)
        XCTAssertNil(decodeFromJSONData(jsonData: data) as Geo?)
    }
    
    func testDecodeWithWrongJSON_ReturnsEmptyObject() {
        let wrongJSON = Data("{\"wrong\": \"json\"}".utf8)
        let actual = decodeFromJSONData(jsonData: wrongJSON) as Geo?
        let expected = Geo()
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecodeWithBrokenJSON_ReturnsNil() {
        let brokenJSON = Data("{\"broken\": \"json\"".utf8)
        XCTAssertNil(decodeFromJSONData(jsonData: brokenJSON) as Geo?)
    }

}
