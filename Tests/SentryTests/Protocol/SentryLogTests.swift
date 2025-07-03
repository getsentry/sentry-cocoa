@_spi(Private) @testable import Sentry
import XCTest

final class SentryLogTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    private let log = SentryLog(
        timestamp: Date(timeIntervalSince1970: 1_234_567_890.987654),
        traceId: SentryId(uuidString: "550e8400-e29b-41d4-a716-446655440000"),
        level: SentryLog.Level.info,
        body: "Test log message",
        attributes: [
            "user_id": .string("12345"),
            "is_active": .boolean(true),
            "count": .integer(42),
            "score": .double(3.14159)
        ],
        severityNumber: 21
    )
    
    private let jsonData = Data("""
    {
        "timestamp": 1234567890.987654,
        "trace_id": "550e8400e29b41d4a716446655440000",
        "level": "trace",
        "body": "Trace message",
        "attributes": {
            "key1": {
                "type": "string",
                "value": "value1"
            },
            "key2": {
                "type": "boolean",
                "value": false
            }
        },
        "severity_number": 21
    }
    """.utf8)
    
    func testEncode() throws {
        let data = try encodeToJSONData(data: log)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["timestamp"] as? TimeInterval, 1_234_567_890.987654)
        XCTAssertEqual(json["trace_id"] as? String, "550e8400e29b41d4a716446655440000")
        XCTAssertEqual(json["level"] as? String, "info")
        XCTAssertEqual(json["body"] as? String, "Test log message")
        
        let encodedAttributes = try XCTUnwrap(json["attributes"] as? [String: [String: Any]])
        XCTAssertEqual(encodedAttributes["user_id"]?["type"] as? String, "string")
        XCTAssertEqual(encodedAttributes["user_id"]?["value"] as? String, "12345")
        XCTAssertEqual(encodedAttributes["is_active"]?["type"] as? String, "boolean")
        XCTAssertEqual(encodedAttributes["is_active"]?["value"] as? Bool, true)
        XCTAssertEqual(encodedAttributes["count"]?["type"] as? String, "integer")
        XCTAssertEqual(encodedAttributes["count"]?["value"] as? Int, 42)
        XCTAssertEqual(encodedAttributes["score"]?["type"] as? String, "double")
        let scoreValue = try XCTUnwrap(encodedAttributes["score"]?["value"] as? Double)
        XCTAssertEqual(scoreValue, 3.14159, accuracy: 0.00001)
        
        XCTAssertEqual(json["severity_number"] as? Int, 21)
    }
    
    func testDecode() throws {
        
        let log = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog?)
        
        XCTAssertEqual(log.timestamp, Date(timeIntervalSince1970: 1_234_567_890.987654))
        XCTAssertEqual(log.traceId.sentryIdString, "550e8400e29b41d4a716446655440000")
        XCTAssertEqual(log.level, .trace)
        XCTAssertEqual(log.body, "Trace message")
        
        XCTAssertEqual(log.attributes.count, 2)
        XCTAssertEqual(log.attributes["key1"]?.type, "string")
        XCTAssertEqual(log.attributes["key1"]?.value as? String, "value1")
        XCTAssertEqual(log.attributes["key2"]?.type, "boolean")
        XCTAssertEqual(log.attributes["key2"]?.value as? Bool, false)
        XCTAssertEqual(log.severityNumber, 21)
    }
    
    func testRoundTrip() throws {
        let data = try encodeToJSONData(data: log)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog?)
        
        XCTAssertEqual(decoded.timestamp, log.timestamp)
        XCTAssertEqual(decoded.traceId.sentryIdString, log.traceId.sentryIdString)
        XCTAssertEqual(decoded.level, log.level)
        XCTAssertEqual(decoded.body, log.body)
        XCTAssertEqual(decoded.severityNumber, log.severityNumber)
        
        XCTAssertEqual(decoded.attributes.count, log.attributes.count)
        
        XCTAssertEqual(decoded.attributes["user_id"]?.type, "string")
        XCTAssertEqual(decoded.attributes["user_id"]?.value as? String, "12345")
        
        XCTAssertEqual(decoded.attributes["is_active"]?.type, "boolean")
        XCTAssertEqual(decoded.attributes["is_active"]?.value as? Bool, true)
        
        XCTAssertEqual(decoded.attributes["count"]?.type, "integer")
        XCTAssertEqual(decoded.attributes["count"]?.value as? Int, 42)
        
        XCTAssertEqual(decoded.attributes["score"]?.type, "double")
        let decodedScoreValue = try XCTUnwrap(decoded.attributes["score"]?.value as? Double)
        XCTAssertEqual(decodedScoreValue, 3.14159, accuracy: 0.00001)
    }
    
    // MARK: - Attribute Initializer Tests
    
    func testAttributeInitializer_AllSupportedTypes() {
        let testValues: [String: Any] = [
            "string_val": "hello",
            "bool_val": true,
            "int_val": 42,
            "double_val": 3.14159,
            "float_val": Float(2.71828),
            "cgfloat_val": CGFloat(1.61803),
            "nsstring_val": NSString("nsstring"),
            "nsnumber_int": NSNumber(value: 123),
            "nsnumber_double": NSNumber(value: 456.789),
            "nsnumber_bool": NSNumber(value: false)
        ]
        
        let result = testValues.mapValues { SentryLog.Attribute(value: $0) }
        
        XCTAssertEqual(result.count, 10)
        
        // Test string conversion
        XCTAssertEqual(result["string_val"]?.type, "string")
        XCTAssertEqual(result["string_val"]?.value as? String, "hello")
        
        // Test boolean conversion
        XCTAssertEqual(result["bool_val"]?.type, "boolean")
        XCTAssertEqual(result["bool_val"]?.value as? Bool, true)
        
        // Test integer conversion
        XCTAssertEqual(result["int_val"]?.type, "integer")
        XCTAssertEqual(result["int_val"]?.value as? Int, 42)
        
        // Test double conversion
        XCTAssertEqual(result["double_val"]?.type, "double")
        XCTAssertEqual(result["double_val"]?.value as? Double, 3.14159)
        
        // Test float to double conversion
        XCTAssertEqual(result["float_val"]?.type, "double")
        let floatAsDouble = result["float_val"]?.value as? Double
        XCTAssertNotNil(floatAsDouble)
        XCTAssertEqual(floatAsDouble!, 2.71828, accuracy: 0.00001)
        
        // Test CGFloat to double conversion
        XCTAssertEqual(result["cgfloat_val"]?.type, "double")
        let cgFloatAsDouble = result["cgfloat_val"]?.value as? Double
        XCTAssertNotNil(cgFloatAsDouble)
        XCTAssertEqual(cgFloatAsDouble!, 1.61803, accuracy: 0.00001)
        
        // Test NSString conversion
        XCTAssertEqual(result["nsstring_val"]?.type, "string")
        XCTAssertEqual(result["nsstring_val"]?.value as? String, "nsstring")
        
        // Test NSNumber integer
        XCTAssertEqual(result["nsnumber_int"]?.type, "integer")
        XCTAssertEqual(result["nsnumber_int"]?.value as? Int, 123)
        
        // Test NSNumber double
        XCTAssertEqual(result["nsnumber_double"]?.type, "double")
        XCTAssertEqual(result["nsnumber_double"]?.value as? Double, 456.789)
        
        // Test NSNumber boolean
        XCTAssertEqual(result["nsnumber_bool"]?.type, "boolean")
        XCTAssertEqual(result["nsnumber_bool"]?.value as? Bool, false)
    }
    
    func testAttributeInitializer_UnsupportedTypesConvertedToString() {
        let customObject = URL(string: "https://example.com")!
        let testValues: [String: Any] = [
            "url": customObject,
            "array": [1, 2, 3],
            "dict": ["key": "value"]
        ]
        
        let result = testValues.mapValues { SentryLog.Attribute(value: $0) }
        
        XCTAssertEqual(result.count, 3)
        
        // Verify unsupported types are converted to strings
        XCTAssertEqual(result["url"]?.type, "string")
        XCTAssertEqual(result["array"]?.type, "string")
        XCTAssertEqual(result["dict"]?.type, "string")
        
        // Verify string representations contain the expected values
        XCTAssertTrue((result["url"]?.value as? String)?.contains("https://example.com") == true)
        XCTAssertTrue((result["array"]?.value as? String)?.contains("1") == true)
        XCTAssertTrue((result["dict"]?.value as? String)?.contains("key") == true)
    }
    
    func testAttributeInitializer_EdgeCases() {
        let testValues: [String: Any] = [
            "zero_int": 0,
            "zero_double": 0.0,
            "negative_int": -42,
            "negative_double": -3.14,
            "empty_string": ""
        ]
        
        let result = testValues.mapValues { SentryLog.Attribute(value: $0) }
        
        XCTAssertEqual(result.count, 5)
        
        // Test zero values
        XCTAssertEqual(result["zero_int"]?.type, "integer")
        XCTAssertEqual(result["zero_int"]?.value as? Int, 0)
        
        XCTAssertEqual(result["zero_double"]?.type, "double")
        XCTAssertEqual(result["zero_double"]?.value as? Double, 0.0)
        
        // Test negative values
        XCTAssertEqual(result["negative_int"]?.type, "integer")
        XCTAssertEqual(result["negative_int"]?.value as? Int, -42)
        
        XCTAssertEqual(result["negative_double"]?.type, "double")
        XCTAssertEqual(result["negative_double"]?.value as? Double, -3.14)
        
        // Test empty string
        XCTAssertEqual(result["empty_string"]?.type, "string")
        XCTAssertEqual(result["empty_string"]?.value as? String, "")
    }
    
    func testAttributeInitializer_EmptyInput() {
        let testValues: [String: Any] = [:]
        
        let result = testValues.mapValues { SentryLog.Attribute(value: $0) }
        
        XCTAssertEqual(result.count, 0)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testAttributeInitializer_SpecialCharactersInKeys() {
        let testValues: [String: Any] = [
            "key with spaces": "value1",
            "key-with-dashes": "value2",
            "key_with_underscores": "value3",
            "keyWithNumbers123": "value4",
            "🔑": "emoji-key"
        ]
        
        let result = testValues.mapValues { SentryLog.Attribute(value: $0) }
        
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result["key with spaces"]?.value as? String, "value1")
        XCTAssertEqual(result["key-with-dashes"]?.value as? String, "value2")
        XCTAssertEqual(result["key_with_underscores"]?.value as? String, "value3")
        XCTAssertEqual(result["keyWithNumbers123"]?.value as? String, "value4")
        XCTAssertEqual(result["🔑"]?.value as? String, "emoji-key")
    }
}
