@testable import Sentry
import XCTest

class SentryArrayTests: XCTestCase {

    func testSanitizeArray_emptyArray_shouldReturnEmptyArray() {
        // Arrange
        let array: [String] = []

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 0)
    }
    
    func testSanitizeArray_withStrings_shouldReturnSameStrings() throws {
        // Arrange
        let array = ["hello", "world", "test"]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        let stringArray = try XCTUnwrap(result as? [String])
        XCTAssertEqual(stringArray, ["hello", "world", "test"])
    }
    
    func testSanitizeArray_withNumbers_shouldReturnSameNumbers() throws {
        // Arrange
        let array = [NSNumber(value: 42), NSNumber(value: 3.14), NSNumber(value: true)]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0] as? NSNumber, NSNumber(value: 42))
        XCTAssertEqual(result[1] as? NSNumber, NSNumber(value: 3.14))
        XCTAssertEqual(result[2] as? NSNumber, NSNumber(value: true))
    }
    
    func testSanitizeArray_withValidDictionaries_shouldReturnSanitizedDictionaries() throws {
        // Arrange
        let dict1: [String: Any] = ["key1": "value1", "key2": NSNumber(value: 123)]
        let dict2: [String: Any] = ["key3": "value3"]
        let array: [Any] = [dict1, dict2]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 2)
        let sanitizedDict1 = try XCTUnwrap(result[0] as? [String: Any])
        let sanitizedDict2 = try XCTUnwrap(result[1] as? [String: Any])
        XCTAssertEqual(sanitizedDict1["key1"] as? String, "value1")
        XCTAssertEqual(sanitizedDict1["key2"] as? NSNumber, NSNumber(value: 123))
        XCTAssertEqual(sanitizedDict2["key3"] as? String, "value3")
    }
    
    func testSanitizeArray_withInvalidDictionary_shouldSkipNilResult() throws {
        // Arrange
        // Create a dictionary-like object that will cause sentry_sanitize to return nil
        let invalidDict = NotReallyADictionary()
        let validDict: [String: Any] = ["key": "value"]
        let array: [Any] = [invalidDict, validDict]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        // Should only contain the valid dictionary, invalid one should be skipped
        XCTAssertEqual(result.count, 1)
        let sanitizedDict = try XCTUnwrap(result[0] as? [String: Any])
        XCTAssertEqual(sanitizedDict["key"] as? String, "value")
    }
    
    func testSanitizeArray_withNestedArrays_shouldRecursivelySanitize() throws {
        // Arrange
        let nestedArray: [Any] = ["nested1", NSNumber(value: 456)]
        let array: [Any] = [nestedArray, "topLevel"]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 2)
        
        let firstElement = try XCTUnwrap(result[0] as? [Any])
        XCTAssertEqual(firstElement[0] as? String, "nested1")
        XCTAssertEqual(firstElement[1] as? NSNumber, NSNumber(value: 456))
        
        XCTAssertEqual(result[1] as? String, "topLevel")
    }
    
    func testSanitizeArray_withDates_shouldConvertToISO8601String() throws {
        // Arrange
        let date1 = Date(timeIntervalSince1970: 1_640_995_200) // 2022-01-01 00:00:00 UTC
        let date2 = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let array: [Any] = [date1, date2]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 2)
        // Verify the dates are converted to strings (ISO8601 format)
        let dateString1 = try XCTUnwrap(result[0] as? String)
        let dateString2 = try XCTUnwrap(result[1] as? String)
        XCTAssertEqual(dateString1, "2022-01-01T00:00:00.000Z")
        XCTAssertEqual(dateString2, "1970-01-01T00:00:00.000Z")
    }
    
    func testSanitizeArray_withOtherObjects_shouldUseDescription() throws {
        // Arrange
        let customObject = CustomObject()
        let array: [Any] = [customObject]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 1)
        let description = try XCTUnwrap(result[0] as? String)
        XCTAssertEqual(description, "CustomObject description")
    }
    
    func testSanitizeArray_withMixedTypes_shouldHandleAllTypes() throws {
        // Arrange
        let dict: [String: Any] = ["key": "value"]
        let nestedArray: [Any] = ["nested"]
        let date = Date(timeIntervalSince1970: 1_640_995_200)
        let customObject = CustomObject()
        let array: [Any] = [
            "string",
            NSNumber(value: 42),
            dict,
            nestedArray,
            date,
            customObject
        ]

        // Act
        let result = SentryArray.sanitizeArray(array)

        // Assert
        XCTAssertEqual(result.count, 6)
        
        // Verify each type is handled correctly
        XCTAssertEqual(result[0] as? String, "string")
        XCTAssertEqual(result[1] as? NSNumber, NSNumber(value: 42))
        XCTAssertNotNil(result[2] as? [String: Any])
        XCTAssertNotNil(result[3] as? [Any])
        
        let dateString = try XCTUnwrap(result[4] as? String)
        XCTAssertEqual(dateString, "2022-01-01T00:00:00.000Z")
        
        let objectDescription = try XCTUnwrap(result[5] as? String)
        XCTAssertEqual(objectDescription, "CustomObject description")
    }
}

// Helper class that inherits from NSObject but is not a real NSDictionary
// This will cause sentry_sanitize to return nil when it checks isSubclassOfClass
private class NotReallyADictionary: NSObject {
    override func isKind(of aClass: AnyClass) -> Bool {
        if aClass == NSDictionary.self {
            return true // Pretend to be a dictionary
        }
        return super.isKind(of: aClass)
    }
}

// Helper class for testing description fallback
private class CustomObject: NSObject {
    override var description: String {
        return "CustomObject description"
    }
}
