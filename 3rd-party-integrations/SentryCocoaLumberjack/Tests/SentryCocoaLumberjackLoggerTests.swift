import CocoaLumberjackSwift
import Sentry
@_spi(Private) @testable import SentryCocoaLumberjack
import XCTest

// swiftlint:disable cyclomatic_complexity file_length type_body_length

final class SentryCocoaLumberjackLoggerTests: XCTestCase {
    
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
    
    private func getSut() -> SentryCocoaLumberjackLogger {
        return SentryCocoaLumberjackLogger()
    }
    
    // MARK: - Basic Logging Tests
    
    func testLog_WithErrorLevel() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test error message",
            formatted: "Test error message",
            level: .error,
            flag: .error,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 100,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .error,
            "Test error message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "error"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "100"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "0")
            ]
        )
    }
    
    func testLog_WithWarningLevel() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test warning message",
            formatted: "Test warning message",
            level: .warning,
            flag: .warning,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 75,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .warn,
            "Test warning message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "warning"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "75"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "0")
            ]
        )
    }
    
    func testLog_WithInfoLevel() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test info message",
            formatted: "Test info message",
            level: .info,
            flag: .info,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 42,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .info,
            "Test info message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "info"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "42"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "0")
            ]
        )
    }
    
    func testLog_WithDebugLevel() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test debug message",
            formatted: "Test debug message",
            level: .debug,
            flag: .debug,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 50,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .debug,
            "Test debug message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "debug"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "50"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "0")
            ]
        )
    }
    
    func testLog_WithVerboseLevel() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test verbose message",
            formatted: "Test verbose message",
            level: .verbose,
            flag: .verbose,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 10,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .trace,
            "Test verbose message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "verbose"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "10"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "0")
            ]
        )
    }
    
    // MARK: - Metadata Tests
    
    func testLog_WithThreadName() throws {
        let sut = getSut()
        let logMessage = DDLogMessage(
            format: "Test with thread name",
            formatted: "Test with thread name",
            level: .info,
            flag: .info,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 20,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        // Thread name is automatically captured by DDLogMessage
        sut.log(message: logMessage)
        
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured")
        
        let capturedLog = try XCTUnwrap(capturedLogs.last)
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with thread name")
        
        // Verify thread ID is present
        XCTAssertNotNil(capturedLog.attributes["cocoalumberjack.threadID"])
    }
    
    func testLog_WithContext() throws {
        let sut = getSut()
        let customContext = 12_345
        let logMessage = DDLogMessage(
            format: "Test with context",
            formatted: "Test with context",
            level: .info,
            flag: .info,
            context: customContext,
            file: "TestFile.swift",
            function: "testFunction",
            line: 30,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: logMessage)
        
        try assertLogCaptured(
            .info,
            "Test with context",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.cocoalumberjack"),
                "cocoalumberjack.level": SentryLog.Attribute(string: "info"),
                "cocoalumberjack.file": SentryLog.Attribute(string: "TestFile.swift"),
                "cocoalumberjack.function": SentryLog.Attribute(string: "testFunction"),
                "cocoalumberjack.line": SentryLog.Attribute(string: "30"),
                "cocoalumberjack.context": SentryLog.Attribute(string: "12345")
            ]
        )
    }
    
    func testLog_WithTimestamp() throws {
        let sut = getSut()
        let customTimestamp = Date(timeIntervalSince1970: 1_234_567_890.123)
        let logMessage = DDLogMessage(
            format: "Test with timestamp",
            formatted: "Test with timestamp",
            level: .info,
            flag: .info,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 40,
            tag: nil,
            options: [],
            timestamp: customTimestamp
        )
        
        sut.log(message: logMessage)
        
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured")
        
        let capturedLog = try XCTUnwrap(capturedLogs.last)
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with timestamp")
        
        // Verify timestamp is captured
        let timestampAttribute = try XCTUnwrap(capturedLog.attributes["cocoalumberjack.timestamp"], "Missing cocoalumberjack.timestamp attribute")
        
        XCTAssertEqual(timestampAttribute.type, "double")
        let timestampValue = try XCTUnwrap(timestampAttribute.value as? Double, "Expected cocoalumberjack.timestamp to be a Double")
        XCTAssertEqual(timestampValue, 1_234_567_890.123, accuracy: 0.001)
    }
    
    // MARK: - Helper Methods
    
    private func assertLogCaptured(
        _ expectedLevel: SentryLog.Level,
        _ expectedBody: String,
        _ expectedAttributes: [String: SentryLog.Attribute],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let capturedLog = getLastCapturedLog(file: file, line: line)
        
        XCTAssertEqual(capturedLog.level, expectedLevel, "Log level mismatch", file: file, line: line)
        XCTAssertEqual(capturedLog.body, expectedBody, "Log body mismatch", file: file, line: line)
        
        // Only verify the user-provided attributes, not the auto-enriched ones
        for (key, expectedAttribute) in expectedAttributes {
            let actualAttribute = try XCTUnwrap(capturedLog.attributes[key], "Missing attribute key: \(key)", file: file, line: line)
            
            XCTAssertEqual(actualAttribute.type, expectedAttribute.type, "Attribute type mismatch for key: \(key)", file: file, line: line)
            
            // Compare values based on type
            switch expectedAttribute.type {
            case "string":
                let expectedValue = try XCTUnwrap(expectedAttribute.value as? String, "Expected string value for expected attribute key: \(key)", file: file, line: line)
                let actualValue = try XCTUnwrap(actualAttribute.value as? String, "Expected string value for actual attribute key: \(key)", file: file, line: line)
                XCTAssertEqual(actualValue, expectedValue, "String attribute value mismatch for key: \(key)", file: file, line: line)
            case "boolean":
                let expectedValue = try XCTUnwrap(expectedAttribute.value as? Bool, "Expected boolean value for expected attribute key: \(key)", file: file, line: line)
                let actualValue = try XCTUnwrap(actualAttribute.value as? Bool, "Expected boolean value for actual attribute key: \(key)", file: file, line: line)
                XCTAssertEqual(actualValue, expectedValue, "Boolean attribute value mismatch for key: \(key)", file: file, line: line)
            case "integer":
                let expectedValue = try XCTUnwrap(expectedAttribute.value as? Int, "Expected integer value for expected attribute key: \(key)", file: file, line: line)
                let actualValue = try XCTUnwrap(actualAttribute.value as? Int, "Expected integer value for actual attribute key: \(key)", file: file, line: line)
                XCTAssertEqual(actualValue, expectedValue, "Integer attribute value mismatch for key: \(key)", file: file, line: line)
            case "double":
                let expectedValue = try XCTUnwrap(expectedAttribute.value as? Double, "Expected double value for expected attribute key: \(key)", file: file, line: line)
                let actualValue = try XCTUnwrap(actualAttribute.value as? Double, "Expected double value for actual attribute key: \(key)", file: file, line: line)
                XCTAssertEqual(actualValue, expectedValue, accuracy: 0.000001, "Double attribute value mismatch for key: \(key)", file: file, line: line)
            default:
                XCTFail("Unknown attribute type for key: \(key). Type: \(expectedAttribute.type)", file: file, line: line)
            }
        }
    }
    
    private func getLastCapturedLog(file: StaticString = #filePath, line: UInt = #line) -> SentryLog {
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured", file: file, line: line)
        guard let lastLog = capturedLogs.last else {
            XCTFail("No logs captured", file: file, line: line)
            return SentryLog(level: .info, body: "", attributes: [:])
        }
        return lastLog
    }
}

// swiftlint:enable cyclomatic_complexity file_length type_body_length
