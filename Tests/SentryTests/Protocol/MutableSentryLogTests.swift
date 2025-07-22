@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class MutableSentryLogTests: XCTestCase {
    
    // MARK: - MutableSentryLog Initialization Tests
    
    func testMutableSentryLog_InitFromSentryLog_CopiesAllProperties() {
        let originalLog = createTestLog(
            level: .error,
            body: "Error message",
            attributes: [
                "user_id": .string("12345"),
                "is_admin": .boolean(true),
                "retry_count": .integer(3),
                "response_time": .double(1.23)
            ]
        )
        
        let mutableLog = MutableSentryLog(log: originalLog)
        
        XCTAssertEqual(mutableLog.timestamp, originalLog.timestamp)
        XCTAssertEqual(mutableLog.traceId, originalLog.traceId)
        XCTAssertEqual(mutableLog.level, .error)
        XCTAssertEqual(mutableLog.body, "Error message")
        XCTAssertEqual(mutableLog.severityNumber?.intValue, originalLog.severityNumber)
        
        // Verify attributes are copied correctly
        XCTAssertEqual(mutableLog.attributes.count, 4)
        XCTAssertEqual(mutableLog.attributes["user_id"] as? String, "12345")
        XCTAssertEqual(mutableLog.attributes["is_admin"] as? Bool, true)
        XCTAssertEqual(mutableLog.attributes["retry_count"] as? Int, 3)
        XCTAssertEqual(mutableLog.attributes["response_time"] as? Double, 1.23)
    }
    
    // MARK: - MutableSentryLog to SentryLog Conversion Tests
    
    func testMutableSentryLog_AllLevels_CorrectSeverityNumbers() {
        let originalLog = createTestLog(level: .info)
        let mutableLog = MutableSentryLog(log: originalLog)
        
        // Test all level to severity number mappings
        let expectedMappings: [(MutableSentryLogLevel, Int)] = [
            (.trace, 1),
            (.debug, 5),
            (.info, 9),
            (.warn, 13),
            (.error, 17),
            (.fatal, 21)
        ]
        
        for (level, expectedSeverity) in expectedMappings {
            mutableLog.level = level
            XCTAssertEqual(mutableLog.severityNumber?.intValue, expectedSeverity, 
                          "Level \(level) should have severity number \(expectedSeverity)")
            
            // Also verify the converted log preserves the severity number
            let convertedLog = mutableLog.toSentryLog()
            XCTAssertEqual(convertedLog.severityNumber, expectedSeverity,
                          "Converted log for level \(level) should have severity number \(expectedSeverity)")
        }
    }
    
    func testMutableSentryLog_ToSentryLog_PreservesAllProperties() throws {
        let originalLog = createTestLog(
            level: .warn,
            body: "Warning message",
            attributes: ["key": .string("value")]
        )
        let mutableLog = MutableSentryLog(log: originalLog)
        
        // Modify some properties
        mutableLog.body = "Modified warning"
        mutableLog.level = .error
        mutableLog.attributes["new_key"] = "new_value"
        
        let convertedLog = mutableLog.toSentryLog()
        
        XCTAssertEqual(convertedLog.timestamp, mutableLog.timestamp)
        XCTAssertEqual(convertedLog.traceId, mutableLog.traceId)
        XCTAssertEqual(convertedLog.level, .error)
        XCTAssertEqual(convertedLog.body, "Modified warning")
        XCTAssertEqual(convertedLog.severityNumber, mutableLog.severityNumber?.intValue)
        
        // Verify attributes conversion
        XCTAssertEqual(convertedLog.attributes.count, 2)
        XCTAssertEqual(convertedLog.attributes["key"]?.value as? String, "value")
        XCTAssertEqual(convertedLog.attributes["new_key"]?.value as? String, "new_value")
    }
    
    func testMutableSentryLog_ToSentryLog_AttributeTypeConversion() {
        let originalLog = createTestLog()
        let mutableLog = MutableSentryLog(log: originalLog)
        
        // Set attributes of different types
        mutableLog.attributes = [
            "string_attr": "test_string",
            "bool_attr": true,
            "int_attr": 42,
            "double_attr": 3.14159,
            "nsstring_attr": NSString("ns_string"),
            "nsnumber_bool": NSNumber(value: false),
            "nsnumber_int": NSNumber(value: 123),
            "nsnumber_double": NSNumber(value: 2.71828)
        ]
        
        let convertedLog = mutableLog.toSentryLog()
        
        XCTAssertEqual(convertedLog.attributes["string_attr"]?.type, "string")
        XCTAssertEqual(convertedLog.attributes["string_attr"]?.value as? String, "test_string")
        
        XCTAssertEqual(convertedLog.attributes["bool_attr"]?.type, "boolean")
        XCTAssertEqual(convertedLog.attributes["bool_attr"]?.value as? Bool, true)
        
        XCTAssertEqual(convertedLog.attributes["int_attr"]?.type, "integer")
        XCTAssertEqual(convertedLog.attributes["int_attr"]?.value as? Int, 42)
        
        XCTAssertEqual(convertedLog.attributes["double_attr"]?.type, "double")
        XCTAssertEqual((convertedLog.attributes["double_attr"]?.value as? Double) ?? 0.0, 3.14159, accuracy: 0.00001)
        
        XCTAssertEqual(convertedLog.attributes["nsstring_attr"]?.type, "string")
        XCTAssertEqual(convertedLog.attributes["nsstring_attr"]?.value as? String, "ns_string")
        
        XCTAssertEqual(convertedLog.attributes["nsnumber_bool"]?.type, "boolean")
        XCTAssertEqual(convertedLog.attributes["nsnumber_bool"]?.value as? Bool, false)
        
        XCTAssertEqual(convertedLog.attributes["nsnumber_int"]?.type, "integer")
        XCTAssertEqual(convertedLog.attributes["nsnumber_int"]?.value as? Int, 123)
        
        XCTAssertEqual(convertedLog.attributes["nsnumber_double"]?.type, "double")
        XCTAssertEqual((convertedLog.attributes["nsnumber_double"]?.value as? Double) ?? 0.0, 2.71828, accuracy: 0.00001)
    }
    
    // Helper
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(),
            traceId: SentryId(),
            level: level,
            body: body,
            attributes: attributes
        )
    }
}
