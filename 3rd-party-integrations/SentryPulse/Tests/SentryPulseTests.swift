import Pulse
import Sentry
@testable import SentryPulse
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryPulseTests: XCTestCase {
    
    private var capturedLogs: [SentryLog] = []
    private var loggerStore: LoggerStore!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        capturedLogs = []
        
        // Create in-memory LoggerStore for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        loggerStore = try LoggerStore(storeURL: tempURL, options: [.inMemory])
        
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
        SentryPulse.stop()
        SentrySDK.close()
        capturedLogs = []
        loggerStore = nil
    }
    
    // MARK: - Basic Logging Tests
    
    func testLog_WithTraceLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .trace,
            message: "Test trace message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured")
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .trace)
        XCTAssertEqual(log.body, "Test trace message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.pulse")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "trace")
        XCTAssertEqual(log.attributes["pulse.label"]?.value as? String, "test")
        XCTAssertEqual(log.attributes["code.file.path"]?.value as? String, "TestFile.swift")
        XCTAssertEqual(log.attributes["code.function.name"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["code.line.number"]?.value as? Int, 1)
    }
    
    func testLog_WithDebugLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .debug,
            message: "Test debug message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .debug)
        XCTAssertEqual(log.body, "Test debug message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "debug")
    }
    
    func testLog_WithInfoLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test info message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.body, "Test info message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "info")
    }
    
    func testLog_WithNoticeLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .notice,
            message: "Test notice message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        // Notice should map to info
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.body, "Test notice message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "notice")
    }
    
    func testLog_WithWarningLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .warning,
            message: "Test warning message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .warn)
        XCTAssertEqual(log.body, "Test warning message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "warning")
    }
    
    func testLog_WithErrorLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .error,
            message: "Test error message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .error)
        XCTAssertEqual(log.body, "Test error message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "error")
    }
    
    func testLog_WithCriticalLevel() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        loggerStore.storeMessage(
            label: "test",
            level: .critical,
            message: "Test critical message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .fatal)
        XCTAssertEqual(log.body, "Test critical message")
        XCTAssertEqual(log.attributes["pulse.level"]?.value as? String, "critical")
    }
    
    // MARK: - Metadata Tests
    
    func testLog_WithMetadata() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        let metadata: [String: LoggerStore.MetadataValue] = [
            "user_id": .string("12345"),
            "session_id": .string("abc-def-ghi")
        ]
        
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test with metadata",
            metadata: metadata,
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["pulse.user_id"]?.value as? String, "12345")
        XCTAssertEqual(log.attributes["pulse.session_id"]?.value as? String, "abc-def-ghi")
    }
    
    func testLog_WithComplexMetadata() throws {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        
        let metadata: [String: LoggerStore.MetadataValue] = [
            "count": .string("42"),
            "enabled": .stringConvertible(true),
            "score": .stringConvertible(3.14159)
        ]
        
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test with complex metadata",
            metadata: metadata,
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.attributes["pulse.count"]?.value as? String, "42")
        XCTAssertEqual(log.attributes["pulse.enabled"]?.value as? String, "true")
        XCTAssertEqual(log.attributes["pulse.score"]?.value as? String, "3.14159")
    }
    
    // MARK: - Integration Lifecycle Tests
    
    func testStaticAPI_CanStartAndStop() {
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "With static API",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        XCTAssertEqual(capturedLogs.count, 1, "Should capture log after start")
        
        SentryPulse.stop()
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "After static stop",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        XCTAssertEqual(capturedLogs.count, 1, "Should not capture additional log after stop")
        
        SentryPulse.startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
        loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "After restart",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        XCTAssertEqual(capturedLogs.count, 2, "Should capture additionallog after restart")
    }
}

// swiftlint:enable cyclomatic_complexity
