import Pulse
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryPulse
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryPulseTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        let batcher: TestLogBatcher
        let sentryLogger: SentryLogger
        let loggerStore: LoggerStore
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryPulseTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            batcher = TestLogBatcher(client: client, dispatchQueue: TestSentryDispatchQueueWrapper())
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
            sentryLogger = SentryLogger(hub: hub, dateProvider: dateProvider, batcher: batcher)
            
            // Create in-memory LoggerStore for testing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            loggerStore = try! LoggerStore(storeURL: tempURL, options: [.inMemory])
        }
        
        func getSut() -> SentryPulse {
            return SentryPulse(loggerStore: loggerStore, sentryLogger: sentryLogger)
        }
    }
    
    private class TestLogBatcher: SentryLogBatcher {
        var addInvocations = Invocations<SentryLog>()
            
        override func add(_ log: SentryLog) {
            addInvocations.record(log)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryPulse!
    
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
    
    func testLog_WithTraceLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .trace,
            message: "Test trace message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .trace,
            "Test trace message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "trace"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithDebugLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .debug,
            message: "Test debug message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .debug,
            "Test debug message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "debug"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithInfoLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test info message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .info,
            "Test info message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "info"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithNoticeLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .notice,
            message: "Test notice message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .info,
            "Test notice message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "notice"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithWarningLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .warning,
            message: "Test warning message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .warn,
            "Test warning message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "warning"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithErrorLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .error,
            message: "Test error message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .error,
            "Test error message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "error"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    func testLog_WithCriticalLevel() {
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .critical,
            message: "Test critical message",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .fatal,
            "Test critical message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "critical"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1")
            ]
        )
    }
    
    // MARK: - Metadata Tests
    
    func testLog_WithMetadata() {
        let metadata: [String: LoggerStore.MetadataValue] = [
            "user_id": .string("12345"),
            "session_id": .string("abc-def-ghi")
        ]
        
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test with metadata",
            metadata: metadata,
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .info,
            "Test with metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "info"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1"),
                "pulse.user_id": SentryLog.Attribute(string: "12345"),
                "pulse.session_id": SentryLog.Attribute(string: "abc-def-ghi")
            ]
        )
    }
    
    func testLog_WithComplexMetadata() {
        let metadata: [String: LoggerStore.MetadataValue] = [
            "count": .string("42"),
            "enabled": .stringConvertible(true),
            "score": .stringConvertible(3.14159)
        ]
        
        fixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "Test with complex metadata",
            metadata: metadata,
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        assertLogCaptured(
            .info,
            "Test with complex metadata",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.pulse"),
                "pulse.level": SentryLog.Attribute(string: "info"),
                "pulse.label": SentryLog.Attribute(string: "test"),
                "pulse.file": SentryLog.Attribute(string: "TestFile.swift"),
                "pulse.function": SentryLog.Attribute(string: "testFunction"),
                "pulse.line": SentryLog.Attribute(string: "1"),
                "pulse.count": SentryLog.Attribute(string: "42"),
                "pulse.enabled": SentryLog.Attribute(string: "true"),
                "pulse.score": SentryLog.Attribute(string: "3.14159")
            ]
        )
    }
    
    // MARK: - Integration Lifecycle Tests
    
    func testStaticAPI_CanStartAndStop() {
        // Use a fresh fixture to avoid contamination from previous tests
        let staticFixture = Fixture()
        
        // Clean up any existing integration
        SentryPulse.stop()
        
        // Start integration with test logger
        SentryPulse.startInternal(loggerStore: staticFixture.loggerStore, sentryLogger: staticFixture.sentryLogger)
        
        // Log should be captured
        staticFixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "With static API",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(staticFixture.batcher.addInvocations.invocations.count, 1, "Should capture log after start")
        
        // Stop integration
        SentryPulse.stop()
        
        // Log should NOT be captured
        staticFixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "After static stop",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(staticFixture.batcher.addInvocations.invocations.count, 1, "Should not capture log after stop")
        
        // Restart integration
        SentryPulse.startInternal(loggerStore: staticFixture.loggerStore, sentryLogger: staticFixture.sentryLogger)
        
        // Log should be captured again
        staticFixture.loggerStore.storeMessage(
            label: "test",
            level: .info,
            message: "After restart",
            metadata: [:],
            file: "TestFile.swift",
            function: "testFunction",
            line: 1
        )
        
        XCTAssertEqual(staticFixture.batcher.addInvocations.invocations.count, 2, "Should capture log after restart")
        
        // Cleanup
        SentryPulse.stop()
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
