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
            "user_id": SentryLog.Attribute(string: "12345"),
            "is_active": SentryLog.Attribute(boolean: true),
            "count": SentryLog.Attribute(integer: 42),
            "score": SentryLog.Attribute(double: 3.14159)
        ],
        severityNumber: NSNumber(value: 21)
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
    
    // MARK: - Severity Number Fallback Tests
    
    func testConstructorWithExplicitSeverityNumber() throws {
        let log = SentryLog(
            timestamp: Date(),
            traceId: SentryId(),
            level: .info,
            body: "Test message",
            attributes: [:],
            severityNumber: 99  // Explicit value different from level's default
        )
        
        XCTAssertEqual(log.severityNumber, 99, "Should use explicitly provided severity number")
        XCTAssertEqual(log.level, .info)
    }
    
    func testConstructorWithoutSeverityNumberFallsBackToLevel() throws {
        let log = SentryLog(
            timestamp: Date(),
            traceId: SentryId(),
            level: .info,
            body: "Test message",
            attributes: [:]
            // severityNumber not provided - should default to nil and fallback to level
        )
        
        XCTAssertEqual(log.severityNumber, 9, "Should derive severity number from info level")
        XCTAssertEqual(log.level, .info)
    }
    
    func testConstructorWithNilSeverityNumberFallsBackToLevel() throws {
        let log = SentryLog(
            timestamp: Date(),
            traceId: SentryId(),
            level: .error,
            body: "Error message",
            attributes: [:],
            severityNumber: nil  // Explicitly nil
        )
        
        XCTAssertEqual(log.severityNumber, 17, "Should derive severity number from error level")
        XCTAssertEqual(log.level, .error)
    }
    
    func testSeverityNumberFallbackForAllLevels() throws {
        let testCases: [(SentryLog.Level, Int)] = [
            (.trace, 1),
            (.debug, 5),
            (.info, 9),
            (.warn, 13),
            (.error, 17),
            (.fatal, 21)
        ]
        
        for (level, expectedSeverity) in testCases {
            let log = SentryLog(
                timestamp: Date(),
                traceId: SentryId(),
                level: level,
                body: "Test message",
                attributes: [:]
                // severityNumber not provided
            )
            
            XCTAssertEqual(log.severityNumber?.intValue, expectedSeverity,
                          "Level \(level) should derive severity number \(expectedSeverity)")
        }
    }

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
}
