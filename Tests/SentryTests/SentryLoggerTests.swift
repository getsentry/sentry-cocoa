@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLoggerTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        let batcher: TestLogBatcher
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLoggerTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            batcher = TestLogBatcher(client: client)
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
        }
        
        func getSut() -> SentryLogger {
            return SentryLogger(hub: hub, dateProvider: dateProvider, batcher: batcher)
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
                "user_id": .string("12345"),
                "is_debug": .boolean(true),
                "count": .integer(42),
                "score": .double(3.14159)
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
                "module": .string("networking"),
                "enabled": .boolean(false)
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
                "request_id": .string("req-123"),
                "duration": .double(1.5)
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
                "retry_count": .integer(3),
                "will_retry": .boolean(true)
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
                "error_code": .integer(500),
                "recoverable": .boolean(false)
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
                "exit_code": .integer(-1),
                "critical": .boolean(true)
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
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 6)
        
        XCTAssertEqual(logs[0].level, .trace)
        XCTAssertEqual(logs[1].level, .debug)
        XCTAssertEqual(logs[2].level, .info)
        XCTAssertEqual(logs[3].level, .warn)
        XCTAssertEqual(logs[4].level, .error)
        XCTAssertEqual(logs[5].level, .fatal)
    }
    
    // MARK: - String Templating Tests
    
    func testInfo_WithMessageTemplating_SingleParameter() {
        sut.info("Adding item %@ for processing", arguments: ["item123"], attributes: ["extra": "data"])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "extra": .string("data"),
            "sentry.message.template": .string("Adding item %@ for processing"),
            "sentry.message.parameter.0": .string("item123")
        ]
        
        assertLogCaptured(
            .info,
            "Adding item item123 for processing",
            expectedAttributes
        )
    }
    
    func testInfo_WithMessageTemplating_MultipleParameters() {
        sut.info("Name: %@, Age: %d, Active: %@, Score: %.1f", 
                arguments: ["Alice", 30, NSNumber(value: true), 95.5], 
                attributes: ["extra": "123"])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "extra": .string("123"),
            "sentry.message.template": .string("Name: %@, Age: %d, Active: %@, Score: %.1f"),
            "sentry.message.parameter.0": .string("Alice"),
            "sentry.message.parameter.1": .integer(30),
            "sentry.message.parameter.2": .boolean(true),
            "sentry.message.parameter.3": .double(95.5)
        ]
        
        assertLogCaptured(
            .info,
            "Name: Alice, Age: 30, Active: 1, Score: 95.5",
            expectedAttributes
        )
    }
    
    func testDebug_WithMessageTemplating() {
        sut.debug("Processing user %@ with ID %@", arguments: ["john_doe", 12_345])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Processing user %@ with ID %@"),
            "sentry.message.parameter.0": .string("john_doe"),
            "sentry.message.parameter.1": .integer(12_345)
        ]
        
        assertLogCaptured(
            .debug,
            "Processing user john_doe with ID 12345",
            expectedAttributes
        )
    }
    
    func testTrace_WithMessageTemplating() {
        sut.trace("Trace event %@", arguments: ["test_event"])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Trace event %@"),
            "sentry.message.parameter.0": .string("test_event")
        ]
        
        assertLogCaptured(
            .trace,
            "Trace event test_event",
            expectedAttributes
        )
    }
    
    func testWarn_WithMessageTemplating() {
        sut.warn("Warning: %@ attempts remaining", arguments: [3])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Warning: %@ attempts remaining"),
            "sentry.message.parameter.0": .integer(3)
        ]
        
        assertLogCaptured(
            .warn,
            "Warning: 3 attempts remaining",
            expectedAttributes
        )
    }
    
    func testError_WithMessageTemplating() {
        sut.error("Error %@ occurred in %@", arguments: [404, "API"])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Error %@ occurred in %@"),
            "sentry.message.parameter.0": .integer(404),
            "sentry.message.parameter.1": .string("API")
        ]
        
        assertLogCaptured(
            .error,
            "Error 404 occurred in API",
            expectedAttributes
        )
    }
    
    func testFatal_WithMessageTemplating() {
        sut.fatal("Fatal error: %@", arguments: ["System crash"])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Fatal error: %@"),
            "sentry.message.parameter.0": .string("System crash")
        ]
        
        assertLogCaptured(
            .fatal,
            "Fatal error: System crash",
            expectedAttributes
        )
    }
    
    func testMessageTemplating_WithEmptyParameters() {
        sut.info("Simple message without parameters", arguments: [])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Simple message without parameters")
        ]
        
        assertLogCaptured(
            .info,
            "Simple message without parameters",
            expectedAttributes
        )
    }
    
    func testMessageTemplating_WithFloatParameter() {
        let floatValue: Float = 2.71828
        sut.info("Pi approximation: %@", arguments: [floatValue])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Pi approximation: %@"),
            "sentry.message.parameter.0": .double(Double(floatValue))
        ]
        
        assertLogCaptured(
            .info,
            "Pi approximation: 2.71828",
            expectedAttributes
        )
    }
    
    func testMessageTemplating_WithComplexTypes() {
        let url = URL(string: "https://example.com")!
        sut.info("Processing URL: %@", arguments: [url.absoluteString])
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "sentry.message.template": .string("Processing URL: %@"),
            "sentry.message.parameter.0": .string("https://example.com")
        ]
        
        assertLogCaptured(
            .info,
            "Processing URL: https://example.com",
            expectedAttributes
        )
    }
    
    func testMessageTemplating_CombinedWithUserAttributes() {
        let userAttributes: [String: Any] = [
            "session_id": "sess_123",
            "user_id": 456,
            "debug_mode": true
        ]
        
        sut.info("User %@ performed action %@", 
                arguments: ["alice", "login"], 
                attributes: userAttributes)
        
        let expectedAttributes: [String: SentryLog.Attribute] = [
            "session_id": .string("sess_123"),
            "user_id": .integer(456),
            "debug_mode": .boolean(true),
            "sentry.message.template": .string("User %@ performed action %@"),
            "sentry.message.parameter.0": .string("alice"),
            "sentry.message.parameter.1": .string("login")
        ]
        
        assertLogCaptured(
            .info,
            "User alice performed action login",
            expectedAttributes
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
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Expected exactly one log to be captured", file: file, line: line)
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured", file: file, line: line)
            return
        }
        
        XCTAssertEqual(capturedLog.level, expectedLevel, "Log level mismatch", file: file, line: line)
        XCTAssertEqual(capturedLog.body, expectedBody, "Log body mismatch", file: file, line: line)
        XCTAssertEqual(capturedLog.timestamp, fixture.dateProvider.date(), "Log timestamp mismatch", file: file, line: line)
        
        // Compare attributes
        XCTAssertEqual(capturedLog.attributes.count, expectedAttributes.count, "Attribute count mismatch", file: file, line: line)
        
        for (key, expectedAttribute) in expectedAttributes {
            guard let actualAttribute = capturedLog.attributes[key] else {
                XCTFail("Missing attribute key: \(key)", file: file, line: line)
                continue
            }
            
            XCTAssertEqual(actualAttribute.type, expectedAttribute.type, "Attribute type mismatch for key: \(key)", file: file, line: line)
            // Compare values based on type
            switch (expectedAttribute, actualAttribute) {
            case let (.string(expected), .string(actual)):
                XCTAssertEqual(actual, expected, "String attribute value mismatch for key: \(key)", file: file, line: line)
            case let (.boolean(expected), .boolean(actual)):
                XCTAssertEqual(actual, expected, "Boolean attribute value mismatch for key: \(key)", file: file, line: line)
            case let (.integer(expected), .integer(actual)):
                XCTAssertEqual(actual, expected, "Integer attribute value mismatch for key: \(key)", file: file, line: line)
            case let (.double(expected), .double(actual)):
                XCTAssertEqual(actual, expected, accuracy: 0.000001, "Double attribute value mismatch for key: \(key)", file: file, line: line)
            default:
                XCTFail("Attribute type mismatch for key: \(key). Expected: \(expectedAttribute.type), Actual: \(actualAttribute.type)", file: file, line: line)
            }
        }
    }
    
    private func getLastCapturedLog() -> SentryLog {
        let logs = fixture.batcher.addInvocations.invocations
        guard let lastLog = logs.last else {
            XCTFail("No logs captured")
            return SentryLog(timestamp: Date(), level: .info, body: "", attributes: [:])
        }
        return lastLog
    }
}

class TestLogBatcher: SentryLogBatcher {
    
    var addInvocations = Invocations<SentryLog>()
    
    override init(client: SentryClient) {
        super.init(client: client)
    }
    
    override func add(_ log: SentryLog) {
        addInvocations.record(log)
    }
}
