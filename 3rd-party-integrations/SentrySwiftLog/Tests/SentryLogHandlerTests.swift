import Logging
import Sentry
@testable import SentrySwiftLog
import XCTest

final class SentryLogHandlerTests: XCTestCase {
    
    private var capturedLogs: [SentryLog] = []
    
    override func setUp() {
        super.setUp()
        capturedLogs = []
        SentrySDK.start { options in
            options.dsn = "https://test@test.ingest.sentry.io/123456"
            options.enableLogs = true
            options.beforeSendLog = { [weak self] log in
                self?.capturedLogs.append(log)
                return nil
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        SentrySDK.close()
        capturedLogs = []
    }
    
    // MARK: - Basic Logging Tests
    
    func testLog_WithInfoLevel() throws {
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .info, message: "Test info message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 42)
        
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured")
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.body, "Test info message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swift-log")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "info")
        XCTAssertEqual(log.attributes["swift-log.source"]?.value as? String, "test")
        XCTAssertEqual(log.attributes["swift-log.file"]?.value as? String, "TestFile.swift")
        XCTAssertEqual(log.attributes["swift-log.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swift-log.line"]?.value as? String, "42")
    }
    
    func testLog_WithErrorLevel() throws {
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .error, message: "Test error message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 100)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .error)
        XCTAssertEqual(log.body, "Test error message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "error")
    }
    
    func testLog_WithTraceLevel() throws {
        let sut = SentryLogHandler(logLevel: .trace)
        sut.log(level: .trace, message: "Test trace message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 1)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .trace)
        XCTAssertEqual(log.body, "Test trace message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "trace")
    }
    
    func testLog_WithDebugLevel() throws {
        let sut = SentryLogHandler(logLevel: .debug)
        sut.log(level: .debug, message: "Test debug message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 50)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .debug)
        XCTAssertEqual(log.body, "Test debug message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "debug")
    }
    
    func testLog_WithWarningLevel() throws {
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .warning, message: "Test warning message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 75)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .warn)
        XCTAssertEqual(log.body, "Test warning message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "warning")
    }
    
    func testLog_WithCriticalLevel() throws {
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .critical, message: "Test critical message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 200)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .fatal)
        XCTAssertEqual(log.body, "Test critical message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "critical")
    }
    
    func testLog_WithNoticeLevel() throws {
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .notice, message: "Test notice message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 150)
        
        // Notice should map to info
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.body, "Test notice message")
        XCTAssertEqual(log.attributes["swift-log.level"]?.value as? String, "notice")
    }
    
    // MARK: - Metadata Tests
    
    func testLog_WithStringMetadata() throws {
        let sut = SentryLogHandler(logLevel: .info)
        let metadata: Logger.Metadata = [
            "user_id": "12345",
            "session_id": "abc-def-ghi"
        ]
        
        sut.log(level: .info, message: "Test with metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 10)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["swift-log.user_id"]?.value as? String, "12345")
        XCTAssertEqual(log.attributes["swift-log.session_id"]?.value as? String, "abc-def-ghi")
    }
    
    func testLog_WithHandlerMetadata() throws {
        var sut = SentryLogHandler(logLevel: .info)
        sut.metadata["app_version"] = "1.0.0"
        sut.metadata["environment"] = "test"
        
        sut.log(level: .info, message: "Test with handler metadata", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 20)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["swift-log.app_version"]?.value as? String, "1.0.0")
        XCTAssertEqual(log.attributes["swift-log.environment"]?.value as? String, "test")
    }
    
    func testLog_WithMergedMetadata() throws {
        var sut = SentryLogHandler(logLevel: .info)
        sut.metadata["app_version"] = "1.0.0"
        
        let logMetadata: Logger.Metadata = [
            "user_id": "12345",
            "app_version": "2.0.0" // This should override handler metadata
        ]
        
        sut.log(level: .info, message: "Test with merged metadata", metadata: logMetadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 30)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["swift-log.user_id"]?.value as? String, "12345")
        XCTAssertEqual(log.attributes["swift-log.app_version"]?.value as? String, "2.0.0") // Should be overridden
    }
    
    func testLog_WithStringConvertibleMetadata() throws {
        let sut = SentryLogHandler(logLevel: .info)
        let metadata: Logger.Metadata = [
            "count": Logger.MetadataValue.stringConvertible(42),
            "enabled": Logger.MetadataValue.stringConvertible(true),
            "score": Logger.MetadataValue.stringConvertible(3.14159)
        ]
        
        sut.log(level: .info, message: "Test with string convertible metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 40)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["swift-log.count"]?.value as? String, "42")
        XCTAssertEqual(log.attributes["swift-log.enabled"]?.value as? String, "true")
        XCTAssertEqual(log.attributes["swift-log.score"]?.value as? String, "3.14159")
    }
    
    func testLog_WithDictionaryMetadata() throws {
        let sut = SentryLogHandler(logLevel: .info)
        let metadata: Logger.Metadata = [
            "user": Logger.MetadataValue.dictionary([
                "id": "12345",
                "name": "John Doe"
            ])
        ]
        
        sut.log(level: .info, message: "Test with dictionary metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 50)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        let userString = log.attributes["swift-log.user"]?.value as? String
        XCTAssertNotNil(userString)
        XCTAssertTrue(userString?.contains("\"id\": \"12345\"") ?? false)
        XCTAssertTrue(userString?.contains("\"name\": \"John Doe\"") ?? false)
    }
    
    func testLog_WithArrayMetadata() throws {
        let sut = SentryLogHandler(logLevel: .info)
        let metadata: Logger.Metadata = [
            "tags": Logger.MetadataValue.array([
                Logger.MetadataValue.string("production"),
                Logger.MetadataValue.string("api"),
                Logger.MetadataValue.stringConvertible(42)
            ])
        ]
        
        sut.log(level: .info, message: "Test with array metadata", metadata: metadata, source: "test", file: "TestFile.swift", function: "testFunction", line: 60)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        let tagsString = log.attributes["swift-log.tags"]?.value as? String
        XCTAssertNotNil(tagsString)
        XCTAssertTrue(tagsString?.contains("\"production\"") ?? false)
        XCTAssertTrue(tagsString?.contains("\"api\"") ?? false)
        XCTAssertTrue(tagsString?.contains("\"42\"") ?? false)
    }
    
    // MARK: - SDK State Tests
    
    func testLog_whenSentrySDKNotEnabled_shouldNotLog() {
        SentrySDK.close()
        
        let sut = SentryLogHandler(logLevel: .info)
        sut.log(level: .info, message: "Test message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 1)
        
        XCTAssertEqual(capturedLogs.count, 0, "Expected no logs when SentrySDK is not enabled")
    }
    
    // MARK: - Log Level Configuration Tests
    
    func testLogLevelConfiguration() {
        let sut = SentryLogHandler(logLevel: .info)
        XCTAssertEqual(sut.logLevel, .info)
    }
    
    func testLogLevelFiltering_InfoThreshold_FiltersTraceAndDebug() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .trace, message: "Trace message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 1)
        sut.log(level: .debug, message: "Debug message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 2)
        
        XCTAssertEqual(capturedLogs.count, 0, "Expected no logs to be captured")
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesInfo() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .info, message: "Info message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 3)
        
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs.first?.level, .info)
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesNotice() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .notice, message: "Notice message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 4)
        
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs.first?.level, .info) // Notice maps to info
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesWarning() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .warning, message: "Warning message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 5)
        
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs.first?.level, .warn)
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesError() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .error, message: "Error message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 6)
        
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs.first?.level, .error)
    }
    
    func testLogLevelFiltering_InfoThreshold_CapturesCritical() {
        let sut = SentryLogHandler(logLevel: .info)
        
        sut.log(level: .critical, message: "Critical message", metadata: nil, source: "test", file: "TestFile.swift", function: "testFunction", line: 7)
        
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs.first?.level, .fatal)
    }
    
    func testMetadataSubscript() {
        var sut = SentryLogHandler(logLevel: .info)
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
}
