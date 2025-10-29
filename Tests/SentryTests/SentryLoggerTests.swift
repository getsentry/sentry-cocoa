@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryLoggerTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLoggerTests")
            options.enableLogs = true
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
        }
        
        func getSut() -> SentryLogger {
            return SentryLogger(hub: hub, dateProvider: dateProvider)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryLogger!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    // MARK: - Trace Level Tests
    
    func testTrace_WithBodyOnly() {
        sut.trace("Test trace message")
        
        assertLogCaptured(
            .trace,
            "Test trace message",
            [:]
        )
    }
    
    func testTrace_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "user_id": "12345",
            "is_debug": true,
            "count": 42,
            "score": 3.14159
        ]
        
        sut.trace("Test trace with attributes", attributes: attributes)
        
        assertLogCaptured(
            .trace,
            "Test trace with attributes",
            [
                "user_id": SentryLog.Attribute(string: "12345"),
                "is_debug": SentryLog.Attribute(boolean: true),
                "count": SentryLog.Attribute(integer: 42),
                "score": SentryLog.Attribute(double: 3.14159)
            ]
        )
    }
    
    // MARK: - Debug Level Tests
    
    func testDebug_WithBodyOnly() {
        sut.debug("Test debug message")
        
        assertLogCaptured(
            .debug,
            "Test debug message",
            [:]
        )
    }
    
    func testDebug_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "module": "networking",
            "enabled": false
        ]
        
        sut.debug("Debug networking", attributes: attributes)
        
        assertLogCaptured(
            .debug,
            "Debug networking",
            [
                "module": SentryLog.Attribute(string: "networking"),
                "enabled": SentryLog.Attribute(boolean: false)
            ]
        )
    }
    
    // MARK: - Info Level Tests
    
    func testInfo_WithBodyOnly() {
        sut.info("Test info message")
        
        assertLogCaptured(
            .info,
            "Test info message",
            [:]
        )
    }
    
    func testInfo_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "request_id": "req-123",
            "duration": 1.5
        ]
        
        sut.info("Request completed", attributes: attributes)
        
        assertLogCaptured(
            .info,
            "Request completed",
            [
                "request_id": SentryLog.Attribute(string: "req-123"),
                "duration": SentryLog.Attribute(double: 1.5)
            ]
        )
    }
    
    // MARK: - Warn Level Tests
    
    func testWarn_WithBodyOnly() {
        sut.warn("Test warning message")
        
        assertLogCaptured(
            .warn,
            "Test warning message",
            [:]
        )
    }
    
    func testWarn_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "retry_count": 3,
            "will_retry": true
        ]
        
        sut.warn("Connection failed", attributes: attributes)
        
        assertLogCaptured(
            .warn,
            "Connection failed",
            [
                "retry_count": SentryLog.Attribute(integer: 3),
                "will_retry": SentryLog.Attribute(boolean: true)
            ]
        )
    }
    
    // MARK: - Error Level Tests
    
    func testError_WithBodyOnly() {
        sut.error("Test error message")
        
        assertLogCaptured(
            .error,
            "Test error message",
            [:]
        )
    }
    
    func testError_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "error_code": 500,
            "recoverable": false
        ]
        
        sut.error("Server error occurred", attributes: attributes)
        
        assertLogCaptured(
            .error,
            "Server error occurred",
            [
                "error_code": SentryLog.Attribute(integer: 500),
                "recoverable": SentryLog.Attribute(boolean: false)
            ]
        )
    }
    
    // MARK: - Fatal Level Tests
    
    func testFatal_WithBodyOnly() {
        sut.fatal("Test fatal message")
        
        assertLogCaptured(
            .fatal,
            "Test fatal message",
            [:]
        )
    }
    
    func testFatal_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "exit_code": -1,
            "critical": true
        ]
        
        sut.fatal("Application crashed", attributes: attributes)
        
        assertLogCaptured(
            .fatal,
            "Application crashed",
            [
                "exit_code": SentryLog.Attribute(integer: -1),
                "critical": SentryLog.Attribute(boolean: true)
            ]
        )
    }
    
    func testEmptyAttributes() {
        sut.info("Empty attributes", attributes: [:])
        
        assertLogCaptured(
            .info,
            "Empty attributes",
            [:]
        )
    }
    
    // MARK: - Date Provider Tests
    
    func testUsesDateProviderForTimestamp() {
        let expectedDate = Date(timeIntervalSince1970: 1_234_567_890.123456)
        fixture.dateProvider.setDate(date: expectedDate)
        
        sut.info("Test timestamp")
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.timestamp, expectedDate)
    }
    
    // MARK: - Multiple Logs Tests
    
    func testMultipleLogsCaptured() {
        sut.trace("Trace message")
        sut.debug("Debug message")
        sut.info("Info message")
        sut.warn("Warn message")
        sut.error("Error message")
        sut.fatal("Fatal message")
        
        // Verify all 6 logs were captured
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 6)
        
        let logs = fixture.client.captureLogInvocations.invocations.map { $0.log }
        XCTAssertEqual(logs[0].level, .trace)
        XCTAssertEqual(logs[1].level, .debug)
        XCTAssertEqual(logs[2].level, .info)
        XCTAssertEqual(logs[3].level, .warn)
        XCTAssertEqual(logs[4].level, .error)
        XCTAssertEqual(logs[5].level, .fatal)
    }
    
    // MARK: - Formatted String Tests
    
    func testTrace_WithFormattedString() {
        let user = "john"
        let count = 42
        let active = true
        let score = 95.5
        
        let logString: SentryLogMessage = "User \(user) processed \(count) items, active: \(active), score: \(score)"
        sut.trace(logString)
        
        assertLogCaptured(
            .trace,
            "User john processed 42 items, active: true, score: 95.5",
            [
                "sentry.message.template": .init(string: "User {0} processed {1} items, active: {2}, score: {3}"),
                "sentry.message.parameter.0": .init(string: "john"),
                "sentry.message.parameter.1": .init(integer: 42),
                "sentry.message.parameter.2": .init(boolean: true),
                "sentry.message.parameter.3": .init(double: 95.5)
            ]
        )
    }
    
    func testTrace_WithFormattedStringAndAttributes() {
        let userId = "user123"
        let logString: SentryLogMessage = "Processing user \(userId)"
        
        sut.trace(logString, attributes: ["extra": "data", "count": 10])
        
        assertLogCaptured(
            .trace,
            "Processing user user123",
            [
                "sentry.message.template": .init(string: "Processing user {0}"),
                "sentry.message.parameter.0": .init(string: "user123"),
                "extra": .init(string: "data"),
                "count": .init(integer: 10)
            ]
        )
    }
    
    func testDebug_WithFormattedString() {
        let value: Float = 3.14
        let enabled = false
        
        let logString: SentryLogMessage = "Float value: \(value), enabled: \(enabled)"
        sut.debug(logString)
        
        assertLogCaptured(
            .debug,
            "Float value: 3.14, enabled: false",
            [
                "sentry.message.template": .init(string: "Float value: {0}, enabled: {1}"),
                "sentry.message.parameter.0": .init(double: Double(value)), // Float is converted to Double
                "sentry.message.parameter.1": .init(boolean: false)
            ]
        )
    }
    
    func testInfo_WithFormattedString() {
        let temperature = 98.6
        let unit = "F"
        
        let logString: SentryLogMessage = "Temperature: \(temperature)°\(unit)"
        sut.info(logString)
        
        assertLogCaptured(
            .info,
            "Temperature: 98.6°F",
            [
                "sentry.message.template": .init(string: "Temperature: {0}°{1}"),
                "sentry.message.parameter.0": .init(double: 98.6),
                "sentry.message.parameter.1": .init(string: "F")
            ]
        )
    }
    
    func testWarn_WithFormattedString() {
        let attempts = 3
        let maxAttempts = 5
        
        let logString: SentryLogMessage = "Retry \(attempts) of \(maxAttempts)"
        sut.warn(logString, attributes: ["retry_policy": "exponential"])
        
        assertLogCaptured(
            .warn,
            "Retry 3 of 5",
            [
                "sentry.message.template": .init(string: "Retry {0} of {1}"),
                "sentry.message.parameter.0": .init(integer: 3),
                "sentry.message.parameter.1": .init(integer: 5),
                "retry_policy": .init(string: "exponential")
            ]
        )
    }
    
    func testError_WithFormattedString() {
        let errorCode = 500
        let service = "payment"
        
        let logString: SentryLogMessage = "Service \(service) failed with code \(errorCode)"
        sut.error(logString)
        
        assertLogCaptured(
            .error,
            "Service payment failed with code 500",
            [
                "sentry.message.template": .init(string: "Service {0} failed with code {1}"),
                "sentry.message.parameter.0": .init(string: "payment"),
                "sentry.message.parameter.1": .init(integer: 500)
            ]
        )
    }
    
    func testFatal_WithFormattedString() {
        let component = "database"
        let critical = true
        
        let logString: SentryLogMessage = "Critical failure in \(component): \(critical)"
        sut.fatal(logString, attributes: ["shutdown": true])
        
        assertLogCaptured(
            .fatal,
            "Critical failure in database: true",
            [
                "sentry.message.template": .init(string: "Critical failure in {0}: {1}"),
                "sentry.message.parameter.0": .init(string: "database"),
                "sentry.message.parameter.1": .init(boolean: true),
                "shutdown": .init(boolean: true)
            ]
        )
    }
    
    func testFormattedString_WithMixedTypes() {
        let name = "test"
        let count = 0
        let percentage = 0.0
        let success = false
        let value: Float = -1.5
        
        let logString: SentryLogMessage = "Test \(name): \(count) items, \(percentage)% complete, success: \(success), float: \(value)"
        sut.debug(logString)
        
        assertLogCaptured(
            .debug,
            "Test test: 0 items, 0.0% complete, success: false, float: -1.5",
            [
                "sentry.message.template": .init(string: "Test {0}: {1} items, {2}% complete, success: {3}, float: {4}"),
                "sentry.message.parameter.0": .init(string: "test"),
                "sentry.message.parameter.1": .init(integer: 0),
                "sentry.message.parameter.2": .init(double: 0.0),
                "sentry.message.parameter.3": .init(boolean: false),
                "sentry.message.parameter.4": .init(double: Double(-1.5))
            ]
        )
    }
    
    func testFormattedString_EmptyAttributes() {
        let logString: SentryLogMessage = "Simple message"
        sut.info(logString, attributes: [:])
        
        assertLogCaptured(
            .info,
            "Simple message",
            [:]  // No template should be added for string literals without interpolations
        )
    }
    
    // MARK: - Helper Methods
    
    private func assertLogCaptured(
        _ expectedLevel: SentryLog.Level,
        _ expectedBody: String,
        _ expectedAttributes: [String: SentryLog.Attribute],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let capturedLog = getLastCapturedLog()
        
        XCTAssertEqual(capturedLog.level, expectedLevel, "Log level mismatch", file: file, line: line)
        XCTAssertEqual(capturedLog.body, expectedBody, "Log body mismatch", file: file, line: line)
        
        // Only verify the user-provided attributes, not the auto-enriched ones
        for (key, expectedAttribute) in expectedAttributes {
            guard let actualAttribute = capturedLog.attributes[key] else {
                XCTFail("Missing attribute key: \(key)", file: file, line: line)
                continue
            }
            
            XCTAssertEqual(actualAttribute.type, expectedAttribute.type, "Attribute type mismatch for key: \(key)", file: file, line: line)
            
            // Compare values based on type
            switch expectedAttribute.type {
            case "string":
                let expectedValue = expectedAttribute.value as! String
                let actualValue = actualAttribute.value as! String
                XCTAssertEqual(actualValue, expectedValue, "String attribute value mismatch for key: \(key)", file: file, line: line)
            case "boolean":
                let expectedValue = expectedAttribute.value as! Bool
                let actualValue = actualAttribute.value as! Bool
                XCTAssertEqual(actualValue, expectedValue, "Boolean attribute value mismatch for key: \(key)", file: file, line: line)
            case "integer":
                let expectedValue = expectedAttribute.value as! Int
                let actualValue = actualAttribute.value as! Int
                XCTAssertEqual(actualValue, expectedValue, "Integer attribute value mismatch for key: \(key)", file: file, line: line)
            case "double":
                let expectedValue = expectedAttribute.value as! Double
                let actualValue = actualAttribute.value as! Double
                XCTAssertEqual(actualValue, expectedValue, accuracy: 0.000001, "Double attribute value mismatch for key: \(key)", file: file, line: line)
            default:
                XCTFail("Unknown attribute type for key: \(key). Type: \(expectedAttribute.type)", file: file, line: line)
            }
        }
    }
    
    private func getLastCapturedLog() -> SentryLog {
        guard let lastInvocation = fixture.client.captureLogInvocations.invocations.last else {
            XCTFail("No logs captured")
            return SentryLog(timestamp: Date(), traceId: .empty, level: .info, body: "", attributes: [:])
        }
        return lastInvocation.log
    }
}
