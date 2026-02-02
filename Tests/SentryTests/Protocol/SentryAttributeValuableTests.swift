@testable import Sentry
import XCTest

final class SentryAttributeValueTests: XCTestCase {
    
    // MARK: - String Extension Tests
    
    func testAsSentryAttributeContent_whenString_shouldReturnStringCase() {
        // -- Arrange --
        let string = "test value"
        
        // -- Act --
        let result = string.asSentryAttributeContent
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test value")
    }
    
    func testAsSentryAttributeContent_whenEmptyString_shouldReturnStringCase() {
        // -- Arrange --
        let string = ""
        
        // -- Act --
        let result = string.asSentryAttributeContent
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "")
    }
    
    // MARK: - Bool Extension Tests
    
    func testAsSentryAttributeContent_whenBoolTrue_shouldReturnBooleanCase() {
        // -- Arrange --
        let bool = true
        
        // -- Act --
        let result = bool.asSentryAttributeContent
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, true)
    }
    
    func testAsSentryAttributeContent_whenBoolFalse_shouldReturnBooleanCase() {
        // -- Arrange --
        let bool = false
        
        // -- Act --
        let result = bool.asSentryAttributeContent
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, false)
    }
    
    // MARK: - Int Extension Tests
    
    func testAsSentryAttributeContent_whenIntPositive_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = 42
        
        // -- Act --
        let result = int.asSentryAttributeContent
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 42)
    }
    
    func testAsSentryAttributeContent_whenIntNegative_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = -42
        
        // -- Act --
        let result = int.asSentryAttributeContent
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, -42)
    }
    
    func testAsSentryAttributeContent_whenIntZero_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = 0
        
        // -- Act --
        let result = int.asSentryAttributeContent
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 0)
    }
    
    // MARK: - Double Extension Tests
    
    func testAsSentryAttributeContent_whenDoublePositive_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = 3.14159
        
        // -- Act --
        let result = double.asSentryAttributeContent
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, 3.14159, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenDoubleNegative_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = -3.14
        
        // -- Act --
        let result = double.asSentryAttributeContent
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, -3.14, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenDoubleZero_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = 0.0
        
        // -- Act --
        let result = double.asSentryAttributeContent
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, 0.0, accuracy: 0.00001)
    }
    
    // MARK: - Float Extension Tests
    
    func testAsSentryAttributeContent_whenFloat_shouldReturnDoubleCase() {
        // -- Arrange --
        let float = Float(2.71828)
        
        // -- Act --
        let result = float.asSentryAttributeContent
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case (Float converted to Double)")
        }
        XCTAssertEqual(value, 2.71828, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenFloatNegative_shouldReturnDoubleCase() {
        // -- Arrange --
        let float = Float(-1.5)
        
        // -- Act --
        let result = float.asSentryAttributeContent
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case (Float converted to Double)")
        }
        XCTAssertEqual(value, -1.5, accuracy: 0.00001)
    }
    
    // MARK: - Array Extension Tests
    
    func testAsSentryAttributeContent_whenStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = ["hello", "world", "test"]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, ["hello", "world", "test"])
    }
    
    func testAsSentryAttributeContent_whenEmptyStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsSentryAttributeContent_whenBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        let array: [Bool] = [true, false, true]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .booleanArray(let value) = result else {
            return XCTFail("Expected .booleanArray case")
        }
        XCTAssertEqual(value, [true, false, true])
    }
    
    func testAsSentryAttributeContent_whenEmptyBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        let array: [Bool] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .booleanArray(let value) = result else {
            return XCTFail("Expected .booleanArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsSentryAttributeContent_whenIntegerArray_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        let array: [Int] = [1, 2, 3, 42]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [1, 2, 3, 42])
    }
    
    func testAsSentryAttributeContent_whenEmptyIntegerArray_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        let array: [Int] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsSentryAttributeContent_whenDoubleArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Double] = [1.1, 2.2, 3.14159]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case")
        }
        XCTAssertEqual(value.count, 3)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(value[2], 3.14159, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenEmptyDoubleArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Double] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsSentryAttributeContent_whenFloatArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Float] = [Float(1.1), Float(2.2), Float(3.14159)]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case (Float array converted to Double array)")
        }
        XCTAssertEqual(value.count, 3)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(value[2], 3.14159, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenEmptyFloatArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Float] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case (Float array converted to Double array)")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsSentryAttributeContent_whenHomogenousStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .string("custom")
            }
        }
        
        let array: [CustomType] = [CustomType(), CustomType()]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        // Since CustomType doesn't match [Bool], [Double], [Float], [Int], or [String],
        // it should fall back to stringArray by converting each element using asSentryAttributeContent
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case (fallback for heterogeneous array)")
        }
        XCTAssertEqual(value, ["custom", "custom"])
    }
    
    func testAsSentryAttributeContent_whenHomogenousBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        struct CustomType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .boolean(true)
            }
        }
        
        let array: [CustomType] = [CustomType(), CustomType()]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        XCTAssertEqual(result, .booleanArray([true, true]))
    }
    
    func testAsSentryAttributeContent_whenHomogenousIntegerArrayWithSingleCustomType_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        struct CustomType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .integer(42)
            }
        }
        
        let array: [CustomType] = [CustomType(), CustomType()]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [42, 42])
    }
    
    func testAsSentryAttributeContent_whenHomogenousIntegerArrayWithDifferentCustomTypes_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        struct CustomIntegerType1: SentryAttributeValue {
            let value: Int
            var asSentryAttributeContent: SentryAttributeContent {
                return .integer(value)
            }
        }
        
        struct CustomIntegerType2: SentryAttributeValue {
            let value: Int
            var asSentryAttributeContent: SentryAttributeContent {
                return .integer(value)
            }
        }
        
        let array: [SentryAttributeValue] = [
            CustomIntegerType1(value: 10),
            CustomIntegerType2(value: 20),
            CustomIntegerType1(value: 30)
        ]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case when different custom types return .integer")
        }
        XCTAssertEqual(value, [10, 20, 30])
    }
    
    func testAsSentryAttributeContent_whenHomogenousDoubleArrayWithDifferentCustomTypes_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        struct CustomDoubleType1: SentryAttributeValue {
            let value: Double
            var asSentryAttributeContent: SentryAttributeContent {
                return .double(value)
            }
        }
        
        struct CustomDoubleType2: SentryAttributeValue {
            let value: Double
            var asSentryAttributeContent: SentryAttributeContent {
                return .double(value)
            }
        }
        
        let array: [SentryAttributeValue] = [
            CustomDoubleType1(value: 1.1),
            CustomDoubleType2(value: 2.2),
            CustomDoubleType1(value: 3.3)
        ]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case when different custom types return .double")
        }
        XCTAssertEqual(value.count, 3)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(value[2], 3.3, accuracy: 0.00001)
    }
    
    func testAsSentryAttributeContent_whenHomogenousStringArrayWithDifferentCustomTypes_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomStringType1: SentryAttributeValue {
            let value: String
            var asSentryAttributeContent: SentryAttributeContent {
                return .string(value)
            }
        }
        
        struct CustomStringType2: SentryAttributeValue {
            let value: String
            var asSentryAttributeContent: SentryAttributeContent {
                return .string(value)
            }
        }
        
        let array: [SentryAttributeValue] = [
            CustomStringType1(value: "first"),
            CustomStringType2(value: "second"),
            CustomStringType1(value: "third")
        ]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case when different custom types return .string")
        }
        XCTAssertEqual(value, ["first", "second", "third"])
    }
    
    func testAsSentryAttributeContent_whenHeterogeneousArrayWithDifferentTypes_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomBoolType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .boolean(false)
            }
        }
        struct CustomDoubleType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .double(123.456)
            }
        }
        struct CustomIntegerType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .integer(42)
            }
        }
        struct CustomStringType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .string("custom")
            }
        }

        let array: [SentryAttributeValue] = [
            CustomBoolType(),
            CustomDoubleType(),
            CustomIntegerType(),
            CustomStringType()
        ]

        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        XCTAssertEqual(result, .stringArray(["false", "123.456", "42", "custom"]))
    }
    
    func testAsSentryAttributeContent_whenSingleElementStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = ["single"]
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, ["single"])
    }
    
    func testAsSentryAttributeContent_whenEmptyCustomAttributeValueArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomStringType: SentryAttributeValue {
            var asSentryAttributeContent: SentryAttributeContent {
                return .string("custom")
            }
        }
        
        let array: [CustomStringType] = []
        
        // -- Act --
        let result = array.asSentryAttributeContent
        
        // -- Assert --
        // Empty arrays of custom SentryAttributeValue types cannot determine the intended type,
        // so they should default to stringArray as a safe fallback
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case for empty custom array (should not be booleanArray)")
        }
        XCTAssertEqual(value, [])
    }
}
