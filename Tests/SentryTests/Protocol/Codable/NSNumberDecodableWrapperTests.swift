@testable import Sentry
import SentryTestUtils
import XCTest

class NSNumberDecodableWrapperTests: XCTestCase {

    func testDecode_BoolTrue() throws {
        // Arrange
        let jsonData = #"""
        {
            "number": true
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertTrue(number.boolValue)
    }
    
    func testDecode_BoolFalse() throws {
        // Arrange
        let jsonData = #"""
        {
            "number": false
        }
        """#.data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertFalse(number.boolValue)
    }

    func testDecode_PositiveInt() throws {
        // Arrange
        let jsonData = #"""
        {
            "number": 1
        }
        """#.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, 1)
    }

    func testDecode_IntMax() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(Int.max)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, Int.max)
    }
    
    func testDecode_IntMin() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(Int.min)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, Int.min)
    }

    func testDecode_UInt32Max() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(UInt32.max)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.uint32Value, UInt32.max)
    }
    
    func testDecode_UInt64Max() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(UInt64.max)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.uint64Value, UInt64.max)
    }
    
    @available(iOS 18, macOS 15, tvOS 18, visionOS 2, *)
    func testDecode_UInt128Max_UsesDouble() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(UInt128.max)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, Double(UInt128.max))
    }

    func testDecode_Zero() throws {
        // Arrange
        let jsonData = """
        {
            "number": 0.0
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, 0)
    }

    func testDecode_Double() throws {
        // Arrange
        let jsonData = """
        {
            "number": 0.1
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, 0.1)
    }

    func testDecode_DoubleMax() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(Double.greatestFiniteMagnitude)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, Double.greatestFiniteMagnitude)
    }

    func testDecode_DoubleMin() throws {
        // Arrange
        let jsonData = """
        {
            "number": \(Double.leastNormalMagnitude)
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, Double.leastNormalMagnitude) 
    }

    func testDecode_Nil() throws {
        // Arrange
        let jsonData = """
        {
            "number": null
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        XCTAssertNil(actual.number)
    }

    func testDecode_String() throws {
        // Arrange
        let jsonData = """
        {
            "number": "hello"
        }
        """.data(using: .utf8)!

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        XCTAssertNil(actual.number)
    }
}

private class ClassWithNSNumber: Decodable {
    
    var number: NSNumber?
    
    enum CodingKeys: String, CodingKey {
        case number
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .number))?.value
    }
}
