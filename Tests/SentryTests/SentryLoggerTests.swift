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
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLoggerTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
        }
        
        func getSut() -> SentryLogger {
            #if SENTRY_TEST || SENTRY_TEST_CI
            return SentryLogger(hub: hub, dateProvider: dateProvider)
            #else
            return SentryLogger(hub: hub)
            #endif
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
            expectedLevel: .trace,
            expectedBody: "Test trace message",
            expectedAttributes: [:]
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
            expectedLevel: .trace,
            expectedBody: "Test trace with attributes",
            expectedAttributes: [
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
            expectedLevel: .debug,
            expectedBody: "Test debug message",
            expectedAttributes: [:]
        )
    }
    
    func testDebug_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "module": "networking",
            "enabled": false
        ]
        
        sut.debug("Debug networking", attributes: attributes)
        
        assertLogCaptured(
            expectedLevel: .debug,
            expectedBody: "Debug networking",
            expectedAttributes: [
                "module": .string("networking"),
                "enabled": .boolean(false)
            ]
        )
    }
    
    // MARK: - Info Level Tests
    
    func testInfo_WithBodyOnly() {
        sut.info("Test info message")
        
        assertLogCaptured(
            expectedLevel: .info,
            expectedBody: "Test info message",
            expectedAttributes: [:]
        )
    }
    
    func testInfo_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "request_id": "req-123",
            "duration": 1.5
        ]
        
        sut.info("Request completed", attributes: attributes)
        
        assertLogCaptured(
            expectedLevel: .info,
            expectedBody: "Request completed",
            expectedAttributes: [
                "request_id": .string("req-123"),
                "duration": .double(1.5)
            ]
        )
    }
    
    // MARK: - Warn Level Tests
    
    func testWarn_WithBodyOnly() {
        sut.warn("Test warning message")
        
        assertLogCaptured(
            expectedLevel: .warn,
            expectedBody: "Test warning message",
            expectedAttributes: [:]
        )
    }
    
    func testWarn_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "retry_count": 3,
            "will_retry": true
        ]
        
        sut.warn("Connection failed", attributes: attributes)
        
        assertLogCaptured(
            expectedLevel: .warn,
            expectedBody: "Connection failed",
            expectedAttributes: [
                "retry_count": .integer(3),
                "will_retry": .boolean(true)
            ]
        )
    }
    
    // MARK: - Error Level Tests
    
    func testError_WithBodyOnly() {
        sut.error("Test error message")
        
        assertLogCaptured(
            expectedLevel: .error,
            expectedBody: "Test error message",
            expectedAttributes: [:]
        )
    }
    
    func testError_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "error_code": 500,
            "recoverable": false
        ]
        
        sut.error("Server error occurred", attributes: attributes)
        
        assertLogCaptured(
            expectedLevel: .error,
            expectedBody: "Server error occurred",
            expectedAttributes: [
                "error_code": .integer(500),
                "recoverable": .boolean(false)
            ]
        )
    }
    
    // MARK: - Fatal Level Tests
    
    func testFatal_WithBodyOnly() {
        sut.fatal("Test fatal message")
        
        assertLogCaptured(
            expectedLevel: .fatal,
            expectedBody: "Test fatal message",
            expectedAttributes: [:]
        )
    }
    
    func testFatal_WithBodyAndAttributes() {
        let attributes: [String: Any] = [
            "exit_code": -1,
            "critical": true
        ]
        
        sut.fatal("Application crashed", attributes: attributes)
        
        assertLogCaptured(
            expectedLevel: .fatal,
            expectedBody: "Application crashed",
            expectedAttributes: [
                "exit_code": .integer(-1),
                "critical": .boolean(true)
            ]
        )
    }
    
    func testEmptyAttributes() {
        sut.info("Empty attributes", attributes: [:])
        
        assertLogCaptured(
            expectedLevel: .info,
            expectedBody: "Empty attributes",
            expectedAttributes: [:]
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
    
    // MARK: - Hub Integration Tests
    
    func testLogsCapturedWithCorrectScope() {
        // Add a tag to the existing scope to verify it's being used
        fixture.hub.configureScope { scope in
            scope.setTag(value: "test-value", key: "test-key")
        }
        
        sut.info("Test scope")
        
        let invocation = fixture.hub.captureLogInvocations.invocations.first
        XCTAssertNotNil(invocation)
        XCTAssertEqual(invocation?.scope.tags["test-key"], "test-value")
    }
    
    func testMultipleLogsCaptured() {
        sut.trace("Trace message")
        sut.debug("Debug message")
        sut.info("Info message")
        sut.warn("Warn message")
        sut.error("Error message")
        sut.fatal("Fatal message")
        
        let invocations = fixture.hub.captureLogInvocations.invocations
        XCTAssertEqual(invocations.count, 6)
        
        XCTAssertEqual(invocations[0].log.level, .trace)
        XCTAssertEqual(invocations[1].log.level, .debug)
        XCTAssertEqual(invocations[2].log.level, .info)
        XCTAssertEqual(invocations[3].log.level, .warn)
        XCTAssertEqual(invocations[4].log.level, .error)
        XCTAssertEqual(invocations[5].log.level, .fatal)
    }
    
    // MARK: - Edge Cases
    
    func testWithVeryLongMessage() {
        let longMessage = String(repeating: "a", count: 10000)
        sut.info(longMessage)
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.body, longMessage)
    }
    
    func testWithEmptyMessage() {
        sut.info("")
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.body, "")
    }
    
    func testWithSpecialCharactersInMessage() {
        let specialMessage = "🚀 Test with émojis and ñ special characters! \n\t\r"
        sut.info(specialMessage)
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.body, specialMessage)
    }
    
    func testWithSpecialCharactersInAttributeKeys() {
        let attributes: [String: Any] = [
            "key with spaces": "value1",
            "key-with-dashes": "value2",
            "key_with_underscores": "value3",
            "keyWithNumbers123": "value4",
            "🔑": "emoji-key"
        ]
        
        sut.info("Special keys", attributes: attributes)
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.attributes.count, 5)
        XCTAssertEqual(capturedLog.attributes["key with spaces"]?.value as? String, "value1")
        XCTAssertEqual(capturedLog.attributes["🔑"]?.value as? String, "emoji-key")
    }
    
    func testWithNilValuesInAttributes() {
        let attributes: [String: Any] = [
            "valid_key": "valid_value"
        ]
        
        // Note: Swift dictionaries can't contain nil values directly,
        // but NSNull could be passed in objective-C contexts
        sut.info("With valid attributes", attributes: attributes)
        
        let capturedLog = getLastCapturedLog()
        XCTAssertEqual(capturedLog.attributes.count, 1)
        XCTAssertEqual(capturedLog.attributes["valid_key"]?.value as? String, "valid_value")
    }
    
    // MARK: - Helper Methods
    
    private func assertLogCaptured(
        expectedLevel: SentryLog.Level,
        expectedBody: String,
        expectedAttributes: [String: SentryLog.Attribute],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let invocations = fixture.hub.captureLogInvocations.invocations
        XCTAssertEqual(invocations.count, 1, "Expected exactly one log to be captured", file: file, line: line)
        
        guard let logInvocation = invocations.first else {
            XCTFail("No log captured", file: file, line: line)
            return
        }
        
        let capturedLog = logInvocation.log
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
        
        XCTAssertEqual(logInvocation.scope, fixture.hub.scope, "Scope mismatch", file: file, line: line)
    }
    
    private func getLastCapturedLog() -> SentryLog {
        let invocations = fixture.hub.captureLogInvocations.invocations
        guard let lastInvocation = invocations.last else {
            XCTFail("No logs captured")
            return SentryLog(timestamp: Date(), level: .info, body: "", attributes: [:])
        }
        return lastInvocation.log
    }
} 
