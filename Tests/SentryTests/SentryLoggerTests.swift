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
        let batcher: TestLogBatcher
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLoggerTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            batcher = TestLogBatcher(client: client, dispatchQueue: TestSentryDispatchQueueWrapper())
            
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
    
    // MARK: - Default Attributes Tests
    
    func testCaptureLog_AddsDefaultAttributes() {
        fixture.options.environment = "test-environment"
        fixture.options.releaseName = "1.0.0"
        
        let span = fixture.hub.startTransaction(name: "Test Transaction", operation: "test-operation")
        fixture.hub.scope.span = span
        
        sut.info("Test log message")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify default attributes were added to the log
        XCTAssertEqual(capturedLog.attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(capturedLog.attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(capturedLog.attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(capturedLog.attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(capturedLog.attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testCaptureLog_DoesNotAddNilDefaultAttributes() {
        fixture.options.releaseName = nil
        
        sut.info("Test log message")
        
        let capturedLog = getLastCapturedLog()
        
        XCTAssertNil(capturedLog.attributes["sentry.release"])
        XCTAssertNil(capturedLog.attributes["sentry.trace.parent_span_id"])
        
        // But should still have the non-nil defaults
        XCTAssertEqual(capturedLog.attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(capturedLog.attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(capturedLog.attributes["sentry.environment"]?.value as? String, fixture.options.environment)
    }

    func testCaptureLog_SetsTraceIdFromPropagationContext() {
        fixture.options.experimental.enableLogs = true
        
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(trace: expectedTraceId, spanId: SpanId())
        
        fixture.hub.scope.propagationContext = propagationContext
        
        sut.info("Test log message with trace ID")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify that the log's trace ID matches the one from the propagation context
        XCTAssertEqual(capturedLog.traceId, expectedTraceId)
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
                "sentry.message.template": .string("User {0} processed {1} items, active: {2}, score: {3}"),
                "sentry.message.parameter.0": .string("john"),
                "sentry.message.parameter.1": .integer(42),
                "sentry.message.parameter.2": .boolean(true),
                "sentry.message.parameter.3": .double(95.5)
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
                "sentry.message.template": .string("Processing user {0}"),
                "sentry.message.parameter.0": .string("user123"),
                "extra": .string("data"),
                "count": .integer(10)
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
                "sentry.message.template": .string("Float value: {0}, enabled: {1}"),
                "sentry.message.parameter.0": .double(Double(value)), // Float is converted to Double
                "sentry.message.parameter.1": .boolean(false)
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
                "sentry.message.template": .string("Temperature: {0}°{1}"),
                "sentry.message.parameter.0": .double(98.6),
                "sentry.message.parameter.1": .string("F")
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
                "sentry.message.template": .string("Retry {0} of {1}"),
                "sentry.message.parameter.0": .integer(3),
                "sentry.message.parameter.1": .integer(5),
                "retry_policy": .string("exponential")
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
                "sentry.message.template": .string("Service {0} failed with code {1}"),
                "sentry.message.parameter.0": .string("payment"),
                "sentry.message.parameter.1": .integer(500)
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
                "sentry.message.template": .string("Critical failure in {0}: {1}"),
                "sentry.message.parameter.0": .string("database"),
                "sentry.message.parameter.1": .boolean(true),
                "shutdown": .boolean(true)
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
                "sentry.message.template": .string("Test {0}: {1} items, {2}% complete, success: {3}, float: {4}"),
                "sentry.message.parameter.0": .string("test"),
                "sentry.message.parameter.1": .integer(0),
                "sentry.message.parameter.2": .double(0.0),
                "sentry.message.parameter.3": .boolean(false),
                "sentry.message.parameter.4": .double(Double(-1.5))
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
    
    // MARK: - User Attributes Tests
    
    func testCaptureLog_AddsUserAttributes() {
        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        
        // Set the user on the scope
        fixture.hub.scope.setUser(user)
        
        sut.info("Test log message with user")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify user attributes were added to the log
        XCTAssertEqual(capturedLog.attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(capturedLog.attributes["user.id"]?.type, "string")
        
        XCTAssertEqual(capturedLog.attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(capturedLog.attributes["user.name"]?.type, "string")
        
        XCTAssertEqual(capturedLog.attributes["user.email"]?.value as? String, "test@test.com")
        XCTAssertEqual(capturedLog.attributes["user.email"]?.type, "string")
    }
    
    func testCaptureLog_DoesNotAddNilUserAttributes() {
        let user = User()
        user.userId = "123"
        // email and name are nil
        
        fixture.hub.scope.setUser(user)
        
        sut.info("Test log message with partial user")
        
        let capturedLog = getLastCapturedLog()
        
        // Should only have user.id
        XCTAssertEqual(capturedLog.attributes["user.id"]?.value as? String, "123")
        XCTAssertNil(capturedLog.attributes["user.name"])
        XCTAssertNil(capturedLog.attributes["user.email"])
    }
    
    func testCaptureLog_DoesNotAddUserAttributesWhenNoUser() {
        // No user set on scope
        
        sut.info("Test log message without user")
        
        let capturedLog = getLastCapturedLog()
        
        // Should not have any user attributes
        XCTAssertNil(capturedLog.attributes["user.id"])
        XCTAssertNil(capturedLog.attributes["user.name"])
        XCTAssertNil(capturedLog.attributes["user.email"])
    }

    func testCaptureLog_AddsOSAndDeviceAttributes() {
        // Set up OS context
        let osContext = [
            "name": "iOS",
            "version": "16.0.1"
        ]
        
        // Set up device context  
        let deviceContext = [
            "family": "iOS",
            "model": "iPhone14,4"
        ]
        
        // Set up scope context
        fixture.hub.scope.setContext(value: osContext, key: "os")
        fixture.hub.scope.setContext(value: deviceContext, key: "device")
        
        sut.info("Test log message")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify OS attributes
        XCTAssertEqual(capturedLog.attributes["os.name"]?.value as? String, "iOS")
        XCTAssertEqual(capturedLog.attributes["os.version"]?.value as? String, "16.0.1")
        
        // Verify device attributes
        XCTAssertEqual(capturedLog.attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertEqual(capturedLog.attributes["device.model"]?.value as? String, "iPhone14,4")
        XCTAssertEqual(capturedLog.attributes["device.family"]?.value as? String, "iOS")
    }
    
    func testCaptureLog_HandlesPartialOSAndDeviceAttributes() {
        // Set up partial OS context (missing version)
        let osContext = [
            "name": "macOS"
        ]
        
        // Set up partial device context (missing model)
        let deviceContext = [
            "family": "macOS"
        ]
        
        // Set up scope context
        fixture.hub.scope.setContext(value: osContext, key: "os")
        fixture.hub.scope.setContext(value: deviceContext, key: "device")
        
        sut.info("Test log message")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify only available OS attributes are added
        XCTAssertEqual(capturedLog.attributes["os.name"]?.value as? String, "macOS")
        XCTAssertNil(capturedLog.attributes["os.version"])
        
        // Verify only available device attributes are added
        XCTAssertEqual(capturedLog.attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertNil(capturedLog.attributes["device.model"])
        XCTAssertEqual(capturedLog.attributes["device.family"]?.value as? String, "macOS")
    }
    
    func testCaptureLog_HandlesMissingOSAndDeviceContext() {
        // Clear any OS and device context that might be automatically populated
        fixture.hub.scope.removeContext(key: "os")
        fixture.hub.scope.removeContext(key: "device")
        
        sut.info("Test log message")
        
        let capturedLog = getLastCapturedLog()
        
        // Verify no OS or device attributes are added when context is missing
        XCTAssertNil(capturedLog.attributes["os.name"])
        XCTAssertNil(capturedLog.attributes["os.version"])
        XCTAssertNil(capturedLog.attributes["device.brand"])
        XCTAssertNil(capturedLog.attributes["device.model"])
        XCTAssertNil(capturedLog.attributes["device.family"])
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
        
        // Count expected default attributes dynamically
        var expectedDefaultAttributeCount = 3 // sdk.name, sdk.version, environment are always present
        if fixture.options.releaseName != nil {
            expectedDefaultAttributeCount += 1 // sentry.release
        }
        if fixture.hub.scope.span != nil {
            expectedDefaultAttributeCount += 1 // sentry.trace.parent_span_id
        }
        // OS and device attributes (up to 5 more if context is available)
        if let contextDictionary = fixture.hub.scope.serialize()["context"] as? [String: [String: Any]] {
            if let osContext = contextDictionary["os"] {
                if osContext["name"] != nil { expectedDefaultAttributeCount += 1 }
                if osContext["version"] != nil { expectedDefaultAttributeCount += 1 }
            }
            if contextDictionary["device"] != nil {
                expectedDefaultAttributeCount += 1 // device.brand (always "Apple")
                if let deviceContext = contextDictionary["device"] {
                    if deviceContext["model"] != nil { expectedDefaultAttributeCount += 1 }
                    if deviceContext["family"] != nil { expectedDefaultAttributeCount += 1 }
                }
            }
        }
        
        // Compare attributes
        XCTAssertEqual(capturedLog.attributes.count, expectedAttributes.count + expectedDefaultAttributeCount, "Attribute count mismatch", file: file, line: line)
        
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
            return SentryLog(timestamp: Date(), traceId: .empty, level: .info, body: "", attributes: [:])
        }
        return lastLog
    }
}

final class TestLogBatcher: SentryLogBatcher {
    
    var addInvocations = Invocations<SentryLog>()
        
    override func add(_ log: SentryLog) {
        addInvocations.record(log)
    }
}
