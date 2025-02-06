@testable import Sentry
import SentryTestUtils
import XCTest

class ArbitraryDataTests: XCTestCase {
    
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
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        XCTAssertEqual("value", actual.data?["some"] as? String)
        XCTAssertEqual("", actual.data?["empty"] as? String)
    }
    
    func testDecode_IntValues() throws {
        // Arrange
        let jsonData = """
        {
            "data": {
                "positive": 1,
                "zero": 0,
                "negative": -1,
                "max": \(Int.max),
                "min": \(Int.min)
            }
        }
        """.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        XCTAssertEqual(1, actual.data?["positive"] as? Int)
        XCTAssertEqual(0, actual.data?["zero"] as? Int)
        XCTAssertEqual(-1, actual.data?["negative"] as? Int)
        XCTAssertEqual(Int.max, actual.data?["max"] as? Int)
        XCTAssertEqual(Int.min, actual.data?["min"] as? Int)
    }

    func testDecode_DoubleValues() throws {
        // Arrange
        let jsonData = """
        {
            "data": {
                "positive": 0.1,
                "negative": -0.1,
                "max": \(Double.greatestFiniteMagnitude),
                "min": \(Double.leastNormalMagnitude)
            }
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        XCTAssertEqual(0.1, actual.data?["positive"] as? Double)
        XCTAssertEqual(-0.1, actual.data?["negative"] as? Double)
        XCTAssertEqual(Double.greatestFiniteMagnitude, actual.data?["max"] as? Double)
        XCTAssertEqual(Double.leastNormalMagnitude, actual.data?["min"] as? Double)
    }

    func testDecode_DoubleWithoutFractionalPart_IsDecodedAsInt() throws {
        // Arrange
        let jsonData = """
        {
            "data": {
                "zero": 0.0,
                "one": 1.0,
                "minus_one": -1.0,

            }
        }
        """.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        XCTAssertEqual(0, actual.data?["zero"] as? Int)
        XCTAssertEqual(1, actual.data?["one"] as? Int)
        XCTAssertEqual(-1, actual.data?["minus_one"] as? Int)
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
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        XCTAssertEqual(true, actual.data?["true"] as? Bool)
        XCTAssertEqual(false, actual.data?["false"] as? Bool)
    }
    
    func testDecode_DateValue() throws {
        // Arrange
        let date = TestCurrentDateProvider().date().addingTimeInterval(0.001)
        let jsonData = #"""
        {
            "data": {
                "date": "\#(sentry_toIso8601String(date))"
            }
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        let actualDate = try XCTUnwrap( actual.data?["date"] as? Date)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 0.0001)
    }
    
    func testDecode_Dict() throws {
        // Arrange
        let jsonData = #"""
        {
            "data": {
                "dict": { 
                    "string": "value",
                    "true": true,
                    "number": 10,
                },
            }
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
        
        // Assert
        let dict = try XCTUnwrap(actual.data?["dict"] as? [String: Any])
        XCTAssertEqual("value", dict["string"] as? String)
        XCTAssertEqual(true, dict["true"] as? Bool)
        XCTAssertEqual(10, dict["number"] as? Int)
    }

    func testDecode_IntArray() throws {
        // Arrange
        let jsonData = #"""
        {
            "data": {
                "array": [1, 2, 3]
            }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        XCTAssertEqual([1, 2, 3], actual.data?["array"] as? [Int])
    }

    func testDecode_ArrayOfDicts() throws {
        // Arrange
        let date = TestCurrentDateProvider().date().addingTimeInterval(0.001)
        let jsonData = #"""
       {
           "data": {
               "array": [
                    { 
                        "dict1_string": "value",
                        "dict1_int": 1,
                    },
                    { 
                        "dict2_number": 0.1,
                        "dict2_date": "\#(sentry_toIso8601String(date))"
                    },
                ]
            }
       }
       """#.data(using: .utf8)!

       // Act
       let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

       // Assert
       let array = try XCTUnwrap(actual.data?["array"] as? [Any])
        XCTAssertEqual(2, array.count)

       let dict1 = try XCTUnwrap(array[0] as? [String: Any])
        
       XCTAssertEqual("value", dict1["dict1_string"] as? String)
       XCTAssertEqual(1, dict1["dict1_int"] as? Int)
        
       let dict2 = try XCTUnwrap(array[1] as? [String: Any])
       XCTAssertEqual(0.1, dict2["dict2_number"] as? Double)
       let actualDate = try XCTUnwrap(dict2["dict2_date"] as? Date)
       XCTAssertEqual(date.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 0.0001)
    }

    func testDecode_NullValue() throws {
        // Arrange
        let jsonData = #"""
        {
            "data": { "null": null }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        XCTAssertEqual(NSNull(), actual.data?["null"] as? NSNull)
    }

    func testDecode_GarbageJSON() {
         // Arrange
        let jsonData = #"""
        {
            "data": {
                1: "garbage"
            }
        }
        """#.data(using: .utf8)!

        // Act & Assert
        XCTAssertNil(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)
    }
    
    func testDecode_Null() throws {
        // Arrange
        let jsonData = #"""
       {
           "data": null
       }
       """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        XCTAssertNil(actual.data)
    }
    
    func testDecodeNestedData_Values() throws {
        // Arrange
        let jsonData = #"""
        {
            "nestedData": { 
                "value": {
                    "key1": "value1",
                    "key2": 2,
                } 
            }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        let nested = try XCTUnwrap(actual.nestedData?["value"] as? [String: Any])
        XCTAssertEqual("value1", nested["key1"] as? String)
        XCTAssertEqual(2, nested["key2"] as? Int)
    }
    
    func testDecodeNestedData_Empty() throws {
        // Arrange
        let jsonData = #"""
        {
            "nestedData": { 
                "value": {
                } 
            }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        let nested = try XCTUnwrap(actual.nestedData?["value"] as? [String: Any])
        XCTAssertTrue(nested.isEmpty)
    }
    
    func testDecodeNestedData_Null() throws {
        // Arrange
        let jsonData = #"""
        {
            "nestedData": { "value": {"nested": null} }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        let nested = try XCTUnwrap(actual.nestedData?["value"] as? [String: Any])
        XCTAssertEqual(NSNull(), nested["nested"] as? NSNull)
    }
    
    func testDecodeNestedData_Garbage() throws {
        // Arrange
        let jsonData = #"""
        {
            "nestedData": { "value": "wrong" }
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as DataWrapper?)

        // Assert
        XCTAssertNil(actual.nestedData)
    }
}

class DataWrapper: Decodable {
    
    var data: [String: Any]?
    var nestedData: [String: [String: Any]]?
    
    enum CodingKeys: String, CodingKey {
        case data
        case nestedData
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .data) as [String: ArbitraryData]?
        }
        self.nestedData = decodeArbitraryData {
            try container.decodeIfPresent([String: [String: ArbitraryData]].self, forKey: .nestedData)
        }
            
    }
}
