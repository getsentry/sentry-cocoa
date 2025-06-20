@testable import Sentry
import XCTest

final class SentryLogTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    let log = SentryLog(
        timestamp: Date(timeIntervalSince1970: 1234567890),
        traceId: SentryId(uuidString: "550e8400-e29b-41d4-a716-446655440000"),
        level: SentryLogLevel.info,
        body: "Test log message",
        attributes: [
            "user_id": .string("12345"),
            "is_active": .bool(true),
            "count": .int(42),
            "score": .double(3.14159)
        ],
        severityNumber: 21
    )
    
    let jsonData = Data("""
    {
        "timestamp": "2009-02-13T23:31:30.000Z",
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
        let data = try JSONEncoder().encode(log)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["timestamp"] as? String, "2009-02-13T23:31:30.000Z")
        XCTAssertEqual(json?["trace_id"] as? String, "550e8400e29b41d4a716446655440000")
        XCTAssertEqual(json?["level"] as? String, "info")
        XCTAssertEqual(json?["body"] as? String, "Test log message")
        
        let encodedAttributes = json?["attributes"] as? [String: [String: Any]]
        XCTAssertNotNil(encodedAttributes)
        XCTAssertEqual(encodedAttributes?["user_id"]?["type"] as? String, "string")
        XCTAssertEqual(encodedAttributes?["user_id"]?["value"] as? String, "12345")
        XCTAssertEqual(encodedAttributes?["is_active"]?["type"] as? String, "boolean")
        XCTAssertEqual(encodedAttributes?["is_active"]?["value"] as? Bool, true)
        XCTAssertEqual(encodedAttributes?["count"]?["type"] as? String, "integer")
        XCTAssertEqual(encodedAttributes?["count"]?["value"] as? Int, 42)
        XCTAssertEqual(encodedAttributes?["score"]?["type"] as? String, "double")
        XCTAssertEqual(encodedAttributes?["score"]?["value"] as! Double, 3.14159, accuracy: 0.00001)
        
        XCTAssertEqual(json?["severity_number"] as? Int, 21)
    }
    
    func testDecode() throws {
        
        let log = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog?)
        
        XCTAssertEqual(log.timestamp, Date(timeIntervalSince1970: 1234567890))
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
        let data = try JSONEncoder().encode(log)
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
        XCTAssertEqual(decoded.attributes["score"]?.value as! Double, 3.14159, accuracy: 0.00001)
    }
}
