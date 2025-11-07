internal import _SentryPrivate
import Logging
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentrySwiftLog
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryLogHandlerTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        let sentryLogger: SentryLogger
        let loggerDelegate: TestLoggerDelegate
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLogTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
            loggerDelegate = TestLoggerDelegate()
            sentryLogger = SentryLogger(delegate: loggerDelegate, dateProvider: dateProvider)
        }
        
        func getSut() -> SentryLogHandler {
            return SentryLogHandler(logLevel: .info, sentryLogger: sentryLogger)
        }
    }
    
    private class TestLoggerDelegate: SentryLoggerDelegate {
        var captureInvocations = Invocations<SentryLog>()
            
        func capture(log: SentryLog) {
            captureInvocations.record(log)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryLogHandler!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    // MARK: - Basic Logging Tests
    
    func testDefaultInit_UsesSDKLogger() throws {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryLogHandlerTests")
        options.enableLogs = true
        let testClient = TestClient(options: options)!
        let testHub = TestHub(client: testClient, andScope: Scope())
        
        SentrySDKInternal.setStart(with: options)
        SentrySDKInternal.setCurrentHub(testHub)
        
        // Create handler with default init (uses SentrySDK.logger)
        let sut = SentryLogHandler(logLevel: .info)
        XCTAssertNotNil(sut)
        
        sut.log(level: .info, message: "Test message from default init", metadata: nil, source: "test", file: "TestFile.swift", function: "testDefaultInit", line: 1)
        SentrySDK.flush(timeout: 0.25)
        
        XCTAssertEqual(1, testHub.captureLogsInvocations.invocations.count)
        let firstLog = try XCTUnwrap(testHub.captureLogsInvocations.invocations.first)
        XCTAssertEqual("Test message from default init", firstLog.body)
        
        SentrySDKInternal.close()
    }
    
    func testLog_WithInfoLevel() {
        sut.log(level: .info, message: "Test info message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 42)
        
        assertLogCaptured(
            .info,
            "Test info message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "42")
            ]
        )
    }
    
    func testLog_WithErrorLevel() {
        sut.log(level: .error, message: "Test error message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 100)
        
        assertLogCaptured(
            .error,
            "Test error message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "error"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "100")
            ]
        )
    }
    
    func testLog_WithTraceLevel() {
        // Set log level to trace to allow trace messages through
        sut.logLevel = .trace
        sut.log(level: .trace, message: "Test trace message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 1)
        
        assertLogCaptured(
            .trace,
            "Test trace message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "trace"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithDebugLevel() {
        // Set log level to debug to allow debug messages through
        sut.logLevel = .debug
        sut.log(level: .debug, message: "Test debug message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 50)
        
        assertLogCaptured(
            .debug,
            "Test debug message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "debug"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "50")
            ]
        )
    }
    
    func testLog_WithWarningLevel() {
        sut.log(level: .warning, message: "Test warning message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 75)
        
        assertLogCaptured(
            .warn,
            "Test warning message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "warning"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "75")
            ]
        )
    }
    
    func testLog_WithCriticalLevel() {
        sut.log(level: .critical, message: "Test critical message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 200)
        
        assertLogCaptured(
            .fatal,
            "Test critical message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "critical"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "200")
            ]
        )
    }
    
    func testLog_WithNoticeLevel() {
        sut.log(level: .notice, message: "Test notice message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 150)
        
        assertLogCaptured(
            .info,
            "Test notice message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "notice"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "150")
            ]
        )
    }
    
    // MARK: - Metadata Tests
    
    func testLog_WithStringMetadata() {
        let metadata: Logger.Metadata = [
            "user_id": "12345",
            "session_id": "abc-def-ghi"
        ]
        
        sut.log(level: .info, message: "Test with metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 10)
        
        assertLogCaptured(
            .info,
            "Test with metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "10"),
                "swift-log.user_id": SentryLog.Attribute(string: "12345"),
                "swift-log.session_id": SentryLog.Attribute(string: "abc-def-ghi")
            ]
        )
    }
    
    func testLog_WithHandlerMetadata() {
        sut.metadata["app_version"] = "1.0.0"
        sut.metadata["environment"] = "test"
        
        sut.log(level: .info, message: "Test with handler metadata", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 20)
        
        assertLogCaptured(
            .info,
            "Test with handler metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "20"),
                "swift-log.app_version": SentryLog.Attribute(string: "1.0.0"),
                "swift-log.environment": SentryLog.Attribute(string: "test")
            ]
        )
    }
    
    func testLog_WithMergedMetadata() {
        sut.metadata["app_version"] = "1.0.0"
        
        let logMetadata: Logger.Metadata = [
            "user_id": "12345",
            "app_version": "2.0.0" // This should override handler metadata
        ]
        
        sut.log(level: .info, message: "Test with merged metadata", metadata: logMetadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 30)
        
        assertLogCaptured(
            .info,
            "Test with merged metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "30"),
                "swift-log.user_id": SentryLog.Attribute(string: "12345"),
                "swift-log.app_version": SentryLog.Attribute(string: "2.0.0")
            ]
        )
    }
    
    // MARK: - Metadata Value Conversion Tests
    
    func testLog_WithStringConvertibleMetadata() {
        let metadata: Logger.Metadata = [
            "count": Logger.MetadataValue.stringConvertible(42),
            "enabled": Logger.MetadataValue.stringConvertible(true),
            "score": Logger.MetadataValue.stringConvertible(3.14159)
        ]
        
        sut.log(level: .info, message: "Test with string convertible metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 40)
        
        assertLogCaptured(
            .info,
            "Test with string convertible metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "40"),
                "swift-log.count": SentryLog.Attribute(string: "42"),
                "swift-log.enabled": SentryLog.Attribute(string: "true"),
                "swift-log.score": SentryLog.Attribute(string: "3.14159")
            ]
        )
    }
    
    func testLog_WithDictionaryMetadata() {
        let metadata: Logger.Metadata = [
            "user": Logger.MetadataValue.dictionary([
                "id": "12345",
                "name": "John Doe"
            ])
        ]
        
        sut.log(level: .info, message: "Test with dictionary metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 50)
        
        // Verify the log was captured
        let logs = fixture.loggerDelegate.captureInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Expected exactly one log to be captured")
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        // Verify basic log properties
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with dictionary metadata")
        
        // Verify the user attribute exists and contains the expected keys
        guard let userAttribute = capturedLog.attributes["swift-log.user"] else {
            XCTFail("Missing swift-log.user attribute")
            return
        }
        
        XCTAssertEqual(userAttribute.type, "string")
        let userString = userAttribute.value as! String
        
        // Check that the string contains both expected key-value pairs (order doesn't matter)
        XCTAssertTrue(userString.contains("\"id\": \"12345\""), "User string should contain id")
        XCTAssertTrue(userString.contains("\"name\": \"John Doe\""), "User string should contain name")
        XCTAssertTrue(userString.hasPrefix("["), "User string should start with [")
        XCTAssertTrue(userString.hasSuffix("]"), "User string should end with ]")
    }
    
    func testLog_WithArrayMetadata() {
        let metadata: Logger.Metadata = [
            "tags": Logger.MetadataValue.array([
                Logger.MetadataValue.string("production"),
                Logger.MetadataValue.string("api"),
                Logger.MetadataValue.stringConvertible(42)
            ])
        ]
        
        sut.log(level: .info, message: "Test with array metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 60)
        
        // Verify the log was captured
        let logs = fixture.loggerDelegate.captureInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Expected exactly one log to be captured")
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        // Verify basic log properties
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with array metadata")
        
        // Verify the tags attribute exists and contains the expected values
        guard let tagsAttribute = capturedLog.attributes["swift-log.tags"] else {
            XCTFail("Missing swift-log.tags attribute")
            return
        }
        
        XCTAssertEqual(tagsAttribute.type, "string")
        let tagsString = tagsAttribute.value as! String
        
        // Check that the string contains all expected values (order might vary)
        XCTAssertTrue(tagsString.contains("\"production\""), "Tags string should contain production")
        XCTAssertTrue(tagsString.contains("\"api\""), "Tags string should contain api")
        XCTAssertTrue(tagsString.contains("\"42\""), "Tags string should contain 42")
        XCTAssertTrue(tagsString.hasPrefix("["), "Tags string should start with [")
        XCTAssertTrue(tagsString.hasSuffix("]"), "Tags string should end with ]")
    }
    
    // MARK: - Log Level Configuration Tests
    
    func testLogLevelConfiguration() {
        XCTAssertEqual(sut.logLevel, .info)
    }
    
    func testLogLevelFiltering_InfoThreshold_FiltersTraceAndDebug() {
        sut.logLevel = .info
        
        sut.log(level: .trace, message: "Trace message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 1)
        sut.log(level: .debug, message: "Debug message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 2)
        
        assertNoLogsCaptured()
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesInfo() {
        sut.logLevel = .info
        
        sut.log(level: .info, message: "Info message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 3)
        
        assertLogCaptured(
            .info,
            "Info message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "info"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "3")
            ]
        )
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesNotice() {
        sut.logLevel = .info
        
        sut.log(level: .notice, message: "Notice message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 4)
        
        assertLogCaptured(
            .info,
            "Notice message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "notice"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "4")
            ]
        )
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesWarning() {
        sut.logLevel = .info
        
        sut.log(level: .warning, message: "Warning message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 5)
        
        assertLogCaptured(
            .warn,
            "Warning message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "warning"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "5")
            ]
        )
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesError() {
        sut.logLevel = .info
        
        sut.log(level: .error, message: "Error message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 6)
        
        assertLogCaptured(
            .error,
            "Error message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "error"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "6")
            ]
        )
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesCritical() {
        sut.logLevel = .info
        
        sut.log(level: .critical, message: "Critical message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 7)
        
        assertLogCaptured(
            .fatal,
            "Critical message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swift-log"),
                "swift-log.level": SentryLog.Attribute(string: "critical"),
                "swift-log.source": SentryLog.Attribute(string: "test"),
                "swift-log.file": SentryLog.Attribute(string: "TestFile.swift"),
                "swift-log.function": SentryLog.Attribute(string: "testFunction"),
                "swift-log.line": SentryLog.Attribute(string: "7")
            ]
        )
    }
    
    func testMetadataSubscript() {
        XCTAssertNil(sut.metadata["test_key"])
        XCTAssertNil(sut[metadataKey: "test_key_2"])
        
        sut.metadata["test_key"] = "test_value"
        XCTAssertEqual(sut.metadata["test_key"], .string("test_value"))

        sut[metadataKey: "test_key_2"] = "test_value_2"
        XCTAssertEqual(sut[metadataKey: "test_key_2"], .string("test_value_2"))
        
        sut.metadata["test_key"] = nil
        XCTAssertNil(sut.metadata["test_key"])

        sut[metadataKey: "test_key_2"] = nil
        XCTAssertNil(sut[metadataKey: "test_key_2"])
    }
    
    // MARK: - Helper Methods
    
    private func assertNoLogsCaptured(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let logs = fixture.loggerDelegate.captureInvocations.invocations
        XCTAssertEqual(logs.count, 0, "Expected no logs to be captured", file: file, line: line)
    }
    
    private func assertLogCaptured(
        _ expectedLevel: SentryLog.Level,
        _ expectedBody: String,
        _ expectedAttributes: [String: SentryLog.Attribute],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let logs = fixture.loggerDelegate.captureInvocations.invocations
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
}
