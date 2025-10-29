import CocoaLumberjackSwift
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryCocoaLumberjack
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryCocoaLumberjackLoggerTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        let batcher: TestLogBatcher
        let sentryLogger: SentryLogger
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryCocoaLumberjackLoggerTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            batcher = TestLogBatcher(client: client, dispatchQueue: TestSentryDispatchQueueWrapper())
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
            sentryLogger = SentryLogger(hub: hub, dateProvider: dateProvider, batcher: batcher)
        }
        
        func getSut(logLevel: DDLogLevel = .all) -> SentryCocoaLumberjackLogger {
            return SentryCocoaLumberjackLogger(logLevel: logLevel, sentryLogger: sentryLogger)
        }
    }
    
    private class TestLogBatcher: SentryLogBatcher {
        var addInvocations = Invocations<SentryLog>()
            
        override func add(_ log: SentryLog) {
            addInvocations.record(log)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryCocoaLumberjackLogger!
    
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
    
    func testLog_WithErrorLevel() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithWarningLevel() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithInfoLevel() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithDebugLevel() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithVerboseLevel() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithThreadName() {
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
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Expected exactly one log to be captured")
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with thread name")
        
        // Verify thread ID is present
        XCTAssertNotNil(capturedLog.attributes["cocoalumberjack.threadID"])
    }
    
    func testLog_WithContext() {
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
        
        assertLogCaptured(
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
    
    func testLog_WithTimestamp() {
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
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Expected exactly one log to be captured")
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test with timestamp")
        
        // Verify timestamp is captured
        guard let timestampAttribute = capturedLog.attributes["cocoalumberjack.timestamp"] else {
            XCTFail("Missing cocoalumberjack.timestamp attribute")
            return
        }
        
        XCTAssertEqual(timestampAttribute.type, "double")
        let timestampValue = timestampAttribute.value as! Double
        XCTAssertEqual(timestampValue, 1_234_567_890.123, accuracy: 0.001)
    }
    
    // MARK: - Log Level Filtering Tests
    
    func testLogLevel_FiltersDebugWhenSetToInfo() {
        sut = fixture.getSut(logLevel: .info)
        
        let debugMessage = DDLogMessage(
            format: "Debug message",
            formatted: "Debug message",
            level: .debug,
            flag: .debug,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 10,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: debugMessage)
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 0, "Debug message should be filtered out when log level is .info")
    }
    
    func testLogLevel_AllowsInfoWhenSetToInfo() {
        sut = fixture.getSut(logLevel: .info)
        
        let infoMessage = DDLogMessage(
            format: "Info message",
            formatted: "Info message",
            level: .info,
            flag: .info,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 10,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: infoMessage)
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Info message should be logged when log level is .info")
    }
    
    func testLogLevel_AllowsErrorWhenSetToInfo() {
        sut = fixture.getSut(logLevel: .info)
        
        let errorMessage = DDLogMessage(
            format: "Error message",
            formatted: "Error message",
            level: .error,
            flag: .error,
            context: 0,
            file: "TestFile.swift",
            function: "testFunction",
            line: 10,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        
        sut.log(message: errorMessage)
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1, "Error message should be logged when log level is .info")
    }
    
    func testLogLevelConfiguration() {
        XCTAssertEqual(sut.logLevel, .all)
        
        sut.logLevel = .info
        XCTAssertEqual(sut.logLevel, .info)
        
        sut.logLevel = .error
        XCTAssertEqual(sut.logLevel, .error)
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
        
        // CocoaLumberjack always adds threadID and timestamp
        let cocoalumberjackAttributeCount = 2 // threadID, timestamp
        
        // Check for optional attributes in captured log
        var optionalCocoalumberjackAttributeCount = 0
        if capturedLog.attributes["cocoalumberjack.threadName"] != nil {
            optionalCocoalumberjackAttributeCount += 1
        }
        if capturedLog.attributes["cocoalumberjack.queueLabel"] != nil {
            optionalCocoalumberjackAttributeCount += 1
        }
        
        // Compare attributes
        let totalExpectedCount = expectedAttributes.count + expectedDefaultAttributeCount + cocoalumberjackAttributeCount + optionalCocoalumberjackAttributeCount
        XCTAssertEqual(capturedLog.attributes.count, totalExpectedCount, "Attribute count mismatch. Expected \(totalExpectedCount), got \(capturedLog.attributes.count)", file: file, line: line)
        
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
