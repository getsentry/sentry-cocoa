@testable import Sentry
import SentryTestUtils
import XCTest

class NSNumberDecodableWrapperTests: XCTestCase {

    func testDecode_BoolTrue() throws {
        // Arrange
        let jsonData = Data(#"""
        {
            "number": true
        }
        """#.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertTrue(number.boolValue)
    }
    
    func testDecode_BoolFalse() throws {
        // Arrange
        let jsonData = Data(#"""
        {
            "number": false
        }
        """#.utf8)
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertFalse(number.boolValue)
    }

    func testDecode_PositiveInt() throws {
        // Arrange
        let jsonData = Data(#"""
        {
            "number": 1
        }
        """#.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, 1)
    }

    func testDecode_IntMax() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(Int.max)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, Int.max)
    }
    
    func testDecode_IntMin() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(Int.min)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, Int.min)
    }

    func testDecode_UInt32Max() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(UInt32.max)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.uint32Value, UInt32.max)
    }
    
    func testDecode_UInt64Max() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(UInt64.max)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.uint64Value, UInt64.max)
    }
    
    // We can't use UInt128.max is only available on iOS 18 and above.
    // Still we would like to test if a max value bigger than UInt64.max is decoded correctly.
    func testDecode_UInt64MaxPlusOne_UsesDouble() throws {
        let UInt64MaxPlusOne = Double(UInt64.max) + 1
        
        // Arrange
        let jsonData = Data("""
        {
            "number": \(UInt64MaxPlusOne)
        }
        """.utf8)
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, UInt64MaxPlusOne)
        
    }

    func testDecode_Zero() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": 0.0
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.intValue, 0)
    }

    func testDecode_Double() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": 0.1
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, 0.1)
    }

    func testDecode_DoubleMax() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(Double.greatestFiniteMagnitude)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, Double.greatestFiniteMagnitude)
    }

    func testDecode_DoubleMin() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": \(Double.leastNormalMagnitude)
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        
        // Assert
        let number = try XCTUnwrap(actual.number)
        XCTAssertEqual(number.doubleValue, Double.leastNormalMagnitude) 
    }

    func testDecode_Nil() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": null
        }
        """.utf8)

        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as ClassWithNSNumber?)
        XCTAssertNil(actual.number)
    }

    func testDecode_String() throws {
        // Arrange
        let jsonData = Data("""
        {
            "number": "hello"
        }
        """.utf8)

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
