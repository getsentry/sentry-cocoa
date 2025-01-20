@testable import Sentry
import SentryTestUtils
import XCTest

class SentryArbitraryDataTests: XCTestCase {
    
    func testDecode_StringValues() throws {
        // Arrange
        let jsonData = #"""
        {
            "data": {
                "some": "value",
                "empty": "",
            }
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ArbitraryData?)
        
        // Assert
        XCTAssertEqual("value", actual.data?["some"] as? String)
        XCTAssertEqual("", actual.data?["empty"] as? String)
    }
    
    func testDecode_BoolValues() throws {
        // Arrange
        let jsonData = #"""
        {
            "data": {
                "true": true,
                "false": false
            }
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ArbitraryData?)
        
        // Assert
        XCTAssertEqual(true, actual.data?["true"] as? Bool)
        XCTAssertEqual(false, actual.data?["false"] as? Bool)
    }
    
    func testDecode_DateValue() throws {
        // Arrange
        let date = TestCurrentDateProvider().date().advanced(by: 0.001)
        let jsonData = #"""
        {
            "data": {
                "date": "\#(sentry_toIso8601String(date))"
            }
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ArbitraryData?)
        
        // Assert
        let actualDate = try XCTUnwrap( actual.data?["date"] as? Date)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 0.0001)
    }
}

class ArbitraryData: Decodable {
    
    var data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: SentryArbitraryData].self, forKey: .data)
        }
    }
}
