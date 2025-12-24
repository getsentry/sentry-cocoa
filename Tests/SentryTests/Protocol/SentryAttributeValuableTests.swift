@testable import Sentry
import XCTest

final class SentryAttributeValuableTests: XCTestCase {
    
    // MARK: - String Extension Tests
    
    func testAsAttributeValue_whenString_shouldReturnStringCase() {
        // -- Arrange --
        let string = "test value"
        
        // -- Act --
        let result = string.asAttributeValue
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test value")
    }
    
    func testAsAttributeValue_whenEmptyString_shouldReturnStringCase() {
        // -- Arrange --
        let string = ""
        
        // -- Act --
        let result = string.asAttributeValue
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "")
    }
    
    // MARK: - Bool Extension Tests
    
    func testAsAttributeValue_whenBoolTrue_shouldReturnBooleanCase() {
        // -- Arrange --
        let bool = true
        
        // -- Act --
        let result = bool.asAttributeValue
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, true)
    }
    
    func testAsAttributeValue_whenBoolFalse_shouldReturnBooleanCase() {
        // -- Arrange --
        let bool = false
        
        // -- Act --
        let result = bool.asAttributeValue
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, false)
    }
    
    // MARK: - Int Extension Tests
    
    func testAsAttributeValue_whenIntPositive_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = 42
        
        // -- Act --
        let result = int.asAttributeValue
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 42)
    }
    
    func testAsAttributeValue_whenIntNegative_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = -42
        
        // -- Act --
        let result = int.asAttributeValue
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, -42)
    }
    
    func testAsAttributeValue_whenIntZero_shouldReturnIntegerCase() {
        // -- Arrange --
        let int = 0
        
        // -- Act --
        let result = int.asAttributeValue
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 0)
    }
    
    // MARK: - Double Extension Tests
    
    func testAsAttributeValue_whenDoublePositive_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = 3.14159
        
        // -- Act --
        let result = double.asAttributeValue
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, 3.14159, accuracy: 0.00001)
    }
    
    func testAsAttributeValue_whenDoubleNegative_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = -3.14
        
        // -- Act --
        let result = double.asAttributeValue
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, -3.14, accuracy: 0.00001)
    }
    
    func testAsAttributeValue_whenDoubleZero_shouldReturnDoubleCase() {
        // -- Arrange --
        let double = 0.0
        
        // -- Act --
        let result = double.asAttributeValue
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, 0.0, accuracy: 0.00001)
    }
    
    // MARK: - Float Extension Tests
    
    func testAsAttributeValue_whenFloat_shouldReturnDoubleCase() {
        // -- Arrange --
        let float = Float(2.71828)
        
        // -- Act --
        let result = float.asAttributeValue
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case (Float converted to Double)")
        }
        XCTAssertEqual(value, 2.71828, accuracy: 0.00001)
    }
    
    func testAsAttributeValue_whenFloatNegative_shouldReturnDoubleCase() {
        // -- Arrange --
        let float = Float(-1.5)
        
        // -- Act --
        let result = float.asAttributeValue
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case (Float converted to Double)")
        }
        XCTAssertEqual(value, -1.5, accuracy: 0.00001)
    }
    
    // MARK: - Array Extension Tests
    
    func testAsAttributeValue_whenStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = ["hello", "world", "test"]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, ["hello", "world", "test"])
    }
    
    func testAsAttributeValue_whenEmptyStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = []
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsAttributeValue_whenBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        let array: [Bool] = [true, false, true]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .booleanArray(let value) = result else {
            return XCTFail("Expected .booleanArray case")
        }
        XCTAssertEqual(value, [true, false, true])
    }
    
    func testAsAttributeValue_whenEmptyBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        let array: [Bool] = []
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .booleanArray(let value) = result else {
            return XCTFail("Expected .booleanArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsAttributeValue_whenIntegerArray_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        let array: [Int] = [1, 2, 3, 42]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [1, 2, 3, 42])
    }
    
    func testAsAttributeValue_whenEmptyIntegerArray_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        let array: [Int] = []
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsAttributeValue_whenDoubleArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Double] = [1.1, 2.2, 3.14159]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case")
        }
        XCTAssertEqual(value.count, 3)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(value[2], 3.14159, accuracy: 0.00001)
    }
    
    func testAsAttributeValue_whenEmptyDoubleArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Double] = []
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsAttributeValue_whenFloatArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Float] = [Float(1.1), Float(2.2), Float(3.14159)]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case (Float array converted to Double array)")
        }
        XCTAssertEqual(value.count, 3)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(value[2], 3.14159, accuracy: 0.00001)
    }
    
    func testAsAttributeValue_whenEmptyFloatArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let array: [Float] = []
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case (Float array converted to Double array)")
        }
        XCTAssertEqual(value, [])
    }
    
    func testAsAttributeValue_whenHomogenousStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .string("custom")
            }
        }
        
        let array: [CustomType] = [CustomType(), CustomType()]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        // Since CustomType doesn't match [Bool], [Double], [Float], [Int], or [String],
        // it should fall back to stringArray by converting each element using asAttributeValue
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case (fallback for heterogeneous array)")
        }
        XCTAssertEqual(value, ["custom", "custom"])
    }
    
    func testAsAttributeValue_whenHomogenousBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        struct CustomType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .boolean(true)
            }
        }
        
        let array: [CustomType] = [CustomType(), CustomType()]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        XCTAssertEqual(result, .booleanArray([true, true]))
    }
    
    func testAsAttributeValue_whenHeterogeneousArrayWithDifferentTypes_shouldReturnStringArrayCase() {
        // -- Arrange --
        struct CustomBoolType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .boolean(false)
            }
        }
        struct CustomDoubleType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .double(123.456)
            }
        }
        struct CustomIntegerType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .integer(42)
            }
        }
        struct CustomStringType: SentryAttributeValuable {
            var asAttributeValue: SentryAttributeValue {
                return .string("custom")
            }
        }

        let array: [SentryAttributeValuable] = [
            CustomBoolType(),
            CustomDoubleType(),
            CustomIntegerType(),
            CustomStringType()
        ]

        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        XCTAssertEqual(result, .stringArray(["false", "123.456", "42", "custom"]))
    }
    
    func testAsAttributeValue_whenSingleElementStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let array: [String] = ["single"]
        
        // -- Act --
        let result = array.asAttributeValue
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, ["single"])
    }
}
