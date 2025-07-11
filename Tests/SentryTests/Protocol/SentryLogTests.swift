@testable import Sentry
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
    
    // MARK: - addAttribute Tests
    
    func testAddAttribute_AddsNewAttributes() {
        var log = SentryLog(
            timestamp: Date(),
            level: .info,
            body: "Test message",
            attributes: [:]
        )
        
        log.addAttribute("string_attr", value: "test_string")
        log.addAttribute("bool_attr", value: true)
        log.addAttribute("int_attr", value: 42)
        log.addAttribute("double_attr", value: 3.14159)
        
        XCTAssertEqual(log.attributes.count, 4)
        
        XCTAssertEqual(log.attributes["string_attr"]?.type, "string")
        XCTAssertEqual(log.attributes["string_attr"]?.value as? String, "test_string")
        
        XCTAssertEqual(log.attributes["bool_attr"]?.type, "boolean")
        XCTAssertEqual(log.attributes["bool_attr"]?.value as? Bool, true)
        
        XCTAssertEqual(log.attributes["int_attr"]?.type, "integer")
        XCTAssertEqual(log.attributes["int_attr"]?.value as? Int, 42)
        
        XCTAssertEqual(log.attributes["double_attr"]?.type, "double")
        XCTAssertEqual(log.attributes["double_attr"]?.value as? Double, 3.14159)
    }
}
