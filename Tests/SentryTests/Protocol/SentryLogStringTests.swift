@testable import Sentry
import XCTest

final class SentryLogStringTests: XCTestCase {
    
    // MARK: - String Literal Tests
    
    func testStringLiteral() {
        let logString: SentryLogString = "Simple string message"
        
        XCTAssertEqual(logString.message, "Simple string message")
        XCTAssertEqual(logString.template, "Simple string message")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testEmptyStringLiteral() {
        let logString: SentryLogString = ""
        
        XCTAssertEqual(logString.message, "")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    // MARK: - String Interpolation Tests
    
    func testStringInterpolation() {
        let value = "test_value"
        let logString: SentryLogString = "User: \(value)"
        
        XCTAssertEqual(logString.message, "User: test_value")
        XCTAssertEqual(logString.template, "User: {0}")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .string(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute")
            return
        }
        XCTAssertEqual(attributeValue, "test_value")
    }
    
    func testBoolInterpolation() {
        let value = true
        let logString: SentryLogString = "Active: \(value)"
        
        XCTAssertEqual(logString.message, "Active: true")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .boolean(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected boolean attribute")
            return
        }
        XCTAssertEqual(attributeValue, true)
    }
    
    func testBoolInterpolationFalse() {
        let value = false
        let logString: SentryLogString = "Enabled: \(value)"
        
        XCTAssertEqual(logString.message, "Enabled: false")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .boolean(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected boolean attribute")
            return
        }
        XCTAssertEqual(attributeValue, false)
    }
    
    func testIntInterpolation() {
        let value = 42
        let logString: SentryLogString = "Count: \(value)"
        
        XCTAssertEqual(logString.message, "Count: 42")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .integer(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(attributeValue, 42)
    }
    
    func testNegativeIntInterpolation() {
        let value = -123
        let logString: SentryLogString = "Value: \(value)"
        
        XCTAssertEqual(logString.message, "Value: -123")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .integer(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(attributeValue, -123)
    }
    
    func testDoubleInterpolation() {
        let value = 3.14159
        let logString: SentryLogString = "Pi: \(value)"
        
        XCTAssertEqual(logString.message, "Pi: 3.14159")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .double(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected double attribute")
            return
        }
        XCTAssertEqual(attributeValue, 3.14159, accuracy: 0.00001)
    }
    
    func testFloatInterpolation() {
        let value: Float = 2.718
        let logString: SentryLogString = "E: \(value)"
        
        XCTAssertEqual(logString.message, "E: 2.718")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .double(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected double attribute (from Float)")
            return
        }
        XCTAssertEqual(attributeValue, Double(value), accuracy: 0.001)
    }
    
    func testNegativeDoubleInterpolation() {
        let value = -3.14159
        let logString: SentryLogString = "Negative Pi: \(value)"
        
        XCTAssertEqual(logString.message, "Negative Pi: -3.14159")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .double(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected double attribute")
            return
        }
        XCTAssertEqual(attributeValue, -3.14159, accuracy: 0.00001)
    }
    
    func testNegativeFloatInterpolation() {
        let value: Float = -2.718
        let logString: SentryLogString = "Negative E: \(value)"
        
        XCTAssertEqual(logString.message, "Negative E: -2.718")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .double(let attributeValue) = logString.attributes[0] else {
            XCTFail("Expected double attribute (from Float)")
            return
        }
        XCTAssertEqual(attributeValue, Double(value), accuracy: 0.001)
    }
    
    // MARK: - Multiple Interpolation Tests
    
    func testMultipleInterpolations() {
        let user = "john"
        let active = true
        let score = 95.5
        let attempts = 3
        
        let logString: SentryLogString = "User \(user) has active=\(active), score=\(score), attempts=\(attempts)"
        
        XCTAssertEqual(logString.message, "User john has active=true, score=95.5, attempts=3")
        XCTAssertEqual(logString.template, "User {0} has active={1}, score={2}, attempts={3}")
        XCTAssertEqual(logString.attributes.count, 4)
        
        guard case .string(let userValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute for user")
            return
        }
        XCTAssertEqual(userValue, "john")
        
        guard case .boolean(let activeValue) = logString.attributes[1] else {
            XCTFail("Expected boolean attribute for active")
            return
        }
        XCTAssertEqual(activeValue, true)
        
        guard case .double(let scoreValue) = logString.attributes[2] else {
            XCTFail("Expected double attribute for score")
            return
        }
        XCTAssertEqual(scoreValue, 95.5, accuracy: 0.001)
        
        guard case .integer(let attemptsValue) = logString.attributes[3] else {
            XCTFail("Expected integer attribute for attempts")
            return
        }
        XCTAssertEqual(attemptsValue, 3)
    }
    
    func testMixedTypesWithLiterals() {
        let count = 10
        let percentage = 85.7
        
        let logString: SentryLogString = "Processing \(count) items with \(percentage)% completion rate"
        
        XCTAssertEqual(logString.message, "Processing 10 items with 85.7% completion rate")
        XCTAssertEqual(logString.attributes.count, 2)
        
        guard case .integer(let countValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(countValue, 10)
        
        guard case .double(let percentageValue) = logString.attributes[1] else {
            XCTFail("Expected double attribute")
            return
        }
        XCTAssertEqual(percentageValue, 85.7, accuracy: 0.001)
    }
    
    // MARK: - Privacy Control Tests
    
    func testPrivateStringInterpolation() {
        let sensitiveValue = "secret-token"
        let logString: SentryLogString = "Accessing \(sensitiveValue, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "Accessing <private>")
        XCTAssertEqual(logString.template, "Accessing {0}")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testPrivateWithTrackedInterpolation() {
        let count = 5
        let sensitiveData = "sensitive-data"
        
        let logString: SentryLogString = "Processing \(count) items with data: \(sensitiveData, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "Processing 5 items with data: <private>")
        XCTAssertEqual(logString.template, "Processing {0} items with data: {1}")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .integer(let countValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(countValue, 5)
    }
    
    func testMixedPublicAndPrivateInterpolation() {
        let publicUserId = "user123"
        let sensitiveToken = "secret-token"
        let publicCount = 5
        let sensitiveFlag = true
        
        let logString: SentryLogString = "User \(publicUserId) with token \(sensitiveToken, privacy: .`private`) processed \(publicCount) items, flag: \(sensitiveFlag, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "User user123 with token <private> processed 5 items, flag: <private>")
        XCTAssertEqual(logString.template, "User {0} with token {1} processed {2} items, flag: {3}")
        XCTAssertEqual(logString.attributes.count, 2) // Only public values should be in attributes
        
        guard case .string(let userIdValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute for userId")
            return
        }
        XCTAssertEqual(userIdValue, "user123")
        
        guard case .integer(let countValue) = logString.attributes[1] else {
            XCTFail("Expected integer attribute for count")
            return
        }
        XCTAssertEqual(countValue, 5)
    }
    
    func testPrivateBoolInterpolation() {
        let sensitiveFlag = true
        let logString: SentryLogString = "Feature enabled: \(sensitiveFlag, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "Feature enabled: <private>")
        XCTAssertEqual(logString.template, "Feature enabled: {0}")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testPrivateIntInterpolation() {
        let sensitiveCount = 42
        let logString: SentryLogString = "Secret count: \(sensitiveCount, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "Secret count: <private>")
        XCTAssertEqual(logString.template, "Secret count: {0}")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testPrivateDoubleInterpolation() {
        let sensitiveValue = 3.14159
        let logString: SentryLogString = "Pi value: \(sensitiveValue, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "Pi value: <private>")
        XCTAssertEqual(logString.template, "Pi value: {0}")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testPrivateFloatInterpolation() {
        let sensitiveFloat: Float = 2.718
        let logString: SentryLogString = "E value: \(sensitiveFloat, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "E value: <private>")
        XCTAssertEqual(logString.template, "E value: {0}")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testExplicitPublicInterpolation() {
        let value = "test"
        let logString: SentryLogString = "Value: \(value, privacy: .`public`)"
        
        XCTAssertEqual(logString.message, "Value: test")
        XCTAssertEqual(logString.template, "Value: {0}")
        XCTAssertEqual(logString.attributes.count, 1)
        
        guard case .string(let stringValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute")
            return
        }
        XCTAssertEqual(stringValue, "test")
    }
    
    func testMixedPrivacyInterpolations() {
        let publicUserId = "user123"
        let sensitiveToken = "secret-token"
        let publicCount = 5
        let sensitiveFlag = true
        
        let logString: SentryLogString = "User \(publicUserId) with token \(sensitiveToken, privacy: .`private`) processed \(publicCount) items, flag: \(sensitiveFlag, privacy: .`private`)"
        
        XCTAssertEqual(logString.message, "User user123 with token <private> processed 5 items, flag: <private>")
        XCTAssertEqual(logString.template, "User {0} with token {1} processed {2} items, flag: {3}")
        XCTAssertEqual(logString.attributes.count, 2)
        
        guard case .string(let userValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute for user")
            return
        }
        XCTAssertEqual(userValue, "user123")
        
        guard case .integer(let countValue) = logString.attributes[1] else {
            XCTFail("Expected integer attribute for count")
            return
        }
        XCTAssertEqual(countValue, 5)
    }
    
    // MARK: - Edge Cases
    
    func testZeroValues() {
        let zero = 0
        let zeroFloat = 0.0
        let emptyString = ""
        
        let logString: SentryLogString = "Zero int: \(zero), zero double: \(zeroFloat), empty: '\(emptyString)'"
        
        XCTAssertEqual(logString.message, "Zero int: 0, zero double: 0.0, empty: ''")
        XCTAssertEqual(logString.attributes.count, 3)
        
        guard case .integer(let zeroValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(zeroValue, 0)
        
        guard case .double(let zeroFloatValue) = logString.attributes[1] else {
            XCTFail("Expected double attribute")
            return
        }
        XCTAssertEqual(zeroFloatValue, 0.0)
        
        guard case .string(let emptyValue) = logString.attributes[2] else {
            XCTFail("Expected string attribute")
            return
        }
        XCTAssertEqual(emptyValue, "")
    }
    
    func testLargeNumbers() {
        let largeInt = Int.max
        let largeDouble = Double.greatestFiniteMagnitude
        
        let logString: SentryLogString = "Large int: \(largeInt), large double: \(largeDouble)"
        
        XCTAssertTrue(logString.message.contains("Large int: \(Int.max)"))
        XCTAssertEqual(logString.attributes.count, 2)
        
        guard case .integer(let largeIntValue) = logString.attributes[0] else {
            XCTFail("Expected integer attribute")
            return
        }
        XCTAssertEqual(largeIntValue, Int.max)
        
        guard case .double(let largeDoubleValue) = logString.attributes[1] else {
            XCTFail("Expected double attribute")
            return
        }
        XCTAssertEqual(largeDoubleValue, Double.greatestFiniteMagnitude)
    }
    
    func testComplexInterpolationPattern() {
        let logString: SentryLogString = "\("prefix") \(42) \(true) \(3.14) \("suffix")"
        
        XCTAssertEqual(logString.message, "prefix 42 true 3.14 suffix")
        XCTAssertEqual(logString.attributes.count, 5)
        
        let expectedTypes = ["string", "integer", "boolean", "double", "string"]
        for (index, expectedType) in expectedTypes.enumerated() {
            XCTAssertEqual(logString.attributes[index].type, expectedType, "Attribute \(index) should be \(expectedType)")
        }
    }
    
    // MARK: - Template Tests
    
    func testStringLiteralTemplate() {
        let logString: SentryLogString = "No interpolation here"
        
        XCTAssertEqual(logString.template, "No interpolation here")
        XCTAssertEqual(logString.message, logString.template)
    }
    
    func testEmptyStringTemplate() {
        let logString: SentryLogString = ""
        
        XCTAssertEqual(logString.template, "")
        XCTAssertEqual(logString.message, "")
    }
    
    func testSingleInterpolationTemplate() {
        let value = "test"
        let logString: SentryLogString = "Value: \(value)"
        
        XCTAssertEqual(logString.template, "Value: {0}")
        XCTAssertEqual(logString.message, "Value: test")
    }
    
    func testMultipleInterpolationsTemplate() {
        let name = "Alice"
        let age = 30
        let active = true
        let score = 95.5
        
        let logString: SentryLogString = "User \(name), age \(age), active: \(active), score: \(score)"
        
        XCTAssertEqual(logString.template, "User {0}, age {1}, active: {2}, score: {3}")
        XCTAssertEqual(logString.message, "User Alice, age 30, active: true, score: 95.5")
    }
    
    func testIntermixedLiteralsAndInterpolations() {
        let userId = "user123"
        let count = 42
        
        let logString: SentryLogString = "Processing user \(userId) with \(count) items completed successfully"
        
        XCTAssertEqual(logString.template, "Processing user {0} with {1} items completed successfully")
        XCTAssertEqual(logString.message, "Processing user user123 with 42 items completed successfully")
    }
    
    func testFloatInterpolationTemplate() {
        let temperature: Float = 98.6
        let humidity = 65.2
        
        let logString: SentryLogString = "Temperature: \(temperature)°F, Humidity: \(humidity)%"
        
        XCTAssertEqual(logString.template, "Temperature: {0}°F, Humidity: {1}%")
        XCTAssertEqual(logString.message, "Temperature: 98.6°F, Humidity: 65.2%")
    }
    
    func testPrivateInterpolationTemplate() {
        let urlString = "https://example.com"
        let logString: SentryLogString = "Accessing \(urlString, privacy: .`private`)"
        
        XCTAssertEqual(logString.template, "Accessing {0}")
        XCTAssertEqual(logString.message, "Accessing <private>")
        XCTAssertTrue(logString.attributes.isEmpty)
    }
    
    func testMixedPublicAndPrivateTemplate() {
        let userId = "alice"
        let sensitiveData = "secret-token-123"
        let count = 5
        
        let logString: SentryLogString = "User \(userId) processed \(count) items with data \(sensitiveData, privacy: .`private`)"
        
        XCTAssertEqual(logString.template, "User {0} processed {1} items with data {2}")
        XCTAssertEqual(logString.attributes.count, 2) // Only public values
        
        guard case .string(let userValue) = logString.attributes[0] else {
            XCTFail("Expected string attribute for user")
            return
        }
        XCTAssertEqual(userValue, "alice")
        
        guard case .integer(let countValue) = logString.attributes[1] else {
            XCTFail("Expected integer attribute for count")
            return
        }
        XCTAssertEqual(countValue, 5)
    }
    
    func testTemplateWithSpecialCharacters() {
        let message = "Hello, World!"
        let percentage = 100.0
        
        let logString: SentryLogString = "Message: \(message) - Complete: \(percentage)%"
        
        XCTAssertEqual(logString.template, "Message: {0} - Complete: {1}%")
        XCTAssertEqual(logString.message, "Message: Hello, World! - Complete: 100.0%")
    }
    
    func testTemplateWithZeroValues() {
        let zeroInt = 0
        let zeroDouble = 0.0
        let emptyString = ""
        let falseValue = false
        
        let logString: SentryLogString = "Int: \(zeroInt), Double: \(zeroDouble), String: '\(emptyString)', Bool: \(falseValue)"
        
        XCTAssertEqual(logString.template, "Int: {0}, Double: {1}, String: '{2}', Bool: {3}")
        XCTAssertEqual(logString.message, "Int: 0, Double: 0.0, String: '', Bool: false")
        XCTAssertEqual(logString.attributes.count, 4)
    }
    
    func testTemplateWithNegativeValues() {
        let negativeInt = -42
        let negativeDouble = -3.14159
        
        let logString: SentryLogString = "Negative int: \(negativeInt), negative double: \(negativeDouble)"
        
        XCTAssertEqual(logString.template, "Negative int: {0}, negative double: {1}")
        XCTAssertEqual(logString.message, "Negative int: -42, negative double: -3.14159")
    }
    
    func testTemplateNumberingSequence() {
        let a = "first"
        let b = "second"
        let c = "third"
        let d = "fourth"
        let e = "fifth"
        
        let logString: SentryLogString = "\(a) \(b) \(c) \(d) \(e)"
        
        XCTAssertEqual(logString.template, "{0} {1} {2} {3} {4}")
        XCTAssertEqual(logString.message, "first second third fourth fifth")
        XCTAssertEqual(logString.attributes.count, 5)
    }
    
    func testTemplateWithOnlyInterpolations() {
        let value1 = "hello"
        let value2 = 42
        
        let logString: SentryLogString = "\(value1)\(value2)"
        
        XCTAssertEqual(logString.template, "{0}{1}")
        XCTAssertEqual(logString.message, "hello42")
    }
    
    func testTemplateStartsAndEndsWithInterpolations() {
        let start = "BEGIN"
        let middle = "middle"
        let end = "END"
        
        let logString: SentryLogString = "\(start) some text \(middle) more text \(end)"
        
        XCTAssertEqual(logString.template, "{0} some text {1} more text {2}")
        XCTAssertEqual(logString.message, "BEGIN some text middle more text END")
    }
    
    func testComplexTemplatePattern() {
        let user = "john"
        let action = "login"
        let timestamp = 1_234_567_890
        let success = true
        let duration = 1.5
        let sensitive = "secret-data"
        
        let logString: SentryLogString = "[\(timestamp)] User '\(user)' performed '\(action)' - Success: \(success), Duration: \(duration)s, Extra: \(sensitive, privacy: .`private`)"
        
        let expectedTemplate = "[{0}] User '{1}' performed '{2}' - Success: {3}, Duration: {4}s, Extra: {5}"
        XCTAssertEqual(logString.template, expectedTemplate)
        
        let expectedMessage = "[1234567890] User 'john' performed 'login' - Success: true, Duration: 1.5s, Extra: <private>"
        XCTAssertEqual(logString.message, expectedMessage)
        
        XCTAssertEqual(logString.attributes.count, 5) // Only public interpolations
    }
}
