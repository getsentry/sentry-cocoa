@testable import Sentry
import XCTest

class SentryCodableTests: XCTestCase {
    
    func testEncodeToJSONData_EncodesCorrectDateFormat() throws {
        let date = Date(timeIntervalSince1970: 1_234_567_890.987_654)
        let jsonData = try encodeToJSONData(data: date)
        let json = String(data: jsonData, encoding: .utf8)
        XCTAssertEqual("1234567890.987654", json)
    }
    
    func testDecode_DecodesFromCorrectDateFormat() throws {
        let json = "\"2009-02-13T23:31:30.000Z\""
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("Could not convert json string to data.")
            return
        }
        let date: Date? = decodeFromJSONData(jsonData: jsonData)
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_234_567_890))
    }
    
    func testDecode_DecodesFromCorrectDateTimestampFormat() throws {
        let json = "1234567890.987654"
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("Could not convert json string to data.")
            return
        }
        let date: Date? = decodeFromJSONData(jsonData: jsonData)
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_234_567_890.987_654))
    }
    
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
