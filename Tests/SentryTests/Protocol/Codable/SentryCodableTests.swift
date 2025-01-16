@testable import Sentry
import XCTest

class SentryCodableTests: XCTestCase {

    func testDecodeWithEmptyData_ReturnsNil() {
        XCTAssertNil(decodeFromJSONData(jsonData: Data()) as Geo?)
    }
    
    func testDecodeWithGarbageData_ReturnsNil() {
        let data = "garbage".data(using: .utf8)!
        XCTAssertNil(decodeFromJSONData(jsonData: data) as Geo?)
    }
    
    func testDecodeWithWrongJSON_ReturnsEmptyObject() {
        let wrongJSON = "{\"wrong\": \"json\"}".data(using: .utf8)!
        let actual = decodeFromJSONData(jsonData: wrongJSON) as Geo?
        let expected = Geo()
        
        XCTAssertEqual(expected, actual)
    }
    
    func testDecodeWithBrokenJSON_ReturnsNil() {
        let brokenJSON = "{\"broken\": \"json\"".data(using: .utf8)!
        XCTAssertNil(decodeFromJSONData(jsonData: brokenJSON) as Geo?)
    }
    
    func testSerializeToJSONObject_ThrowsError_ReturnsEmptyDict() throws {
        let sut = FailingEncodable()
        
        let actual = try XCTUnwrap( addsPerformanceOverhead_serializeToJSONObject(sut) as [String: Any])
        XCTAssertTrue(actual.isEmpty)
    }
    
    class FailingEncodable: Encodable {
        func encode(to encoder: Encoder) throws {
            throw NSError(domain: "test", code: -1, userInfo: nil)
        }
    }

}
