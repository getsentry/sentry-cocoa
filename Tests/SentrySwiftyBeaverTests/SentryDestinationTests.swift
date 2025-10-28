@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentrySwiftyBeaver
@_spi(Private) import SentryTestUtils
import SwiftyBeaver
import XCTest

// swiftlint:disable cyclomatic_complexity

final class SentryDestinationTests: XCTestCase {
    
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
            options.dsn = TestConstants.dsnAsString(username: "SentryDestinationTests")
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            batcher = TestLogBatcher(client: client, dispatchQueue: TestSentryDispatchQueueWrapper())
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
            sentryLogger = SentryLogger(hub: hub, dateProvider: dateProvider, batcher: batcher)
        }
        
        func getSut() -> SentryDestination {
            return SentryDestination(sentryLogger: sentryLogger)
        }
    }
    
    private class TestLogBatcher: SentryLogBatcher {
        var addInvocations = Invocations<SentryLog>()
            
        override func add(_ log: SentryLog) {
            addInvocations.record(log)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryDestination!
    
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
    
    func testVerboseMapsToTrace() {
        let result = sut.send(.verbose, msg: "Verbose message", thread: "main", file: "Test.swift", function: "testFunction", line: 42)
        
        assertLogCaptured(
            .trace,
            "Verbose message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "0"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "42")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testDebugMapsToDebug() {
        let result = sut.send(.debug, msg: "Debug message", thread: "main", file: "Test.swift", function: "testFunction", line: 50)
        
        assertLogCaptured(
            .debug,
            "Debug message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "1"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "50")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testInfoMapsToInfo() {
        let result = sut.send(.info, msg: "Info message", thread: "main", file: "Test.swift", function: "testFunction", line: 100)
        
        assertLogCaptured(
            .info,
            "Info message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "2"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "100")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testWarningMapsToWarn() {
        let result = sut.send(.warning, msg: "Warning message", thread: "main", file: "Test.swift", function: "testFunction", line: 75)
        
        assertLogCaptured(
            .warn,
            "Warning message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "3"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "75")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testErrorMapsToError() {
        let result = sut.send(.error, msg: "Error message", thread: "main", file: "Test.swift", function: "testFunction", line: 200)
        
        assertLogCaptured(
            .error,
            "Error message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "4"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "200")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testCriticalMapsToFatal() {
        let result = sut.send(.critical, msg: "Critical message", thread: "main", file: "Test.swift", function: "testFunction", line: 250)
        
        assertLogCaptured(
            .fatal,
            "Critical message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "5"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "250")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testFaultMapsToFatal() {
        let result = sut.send(.fault, msg: "Fault message", thread: "main", file: "Test.swift", function: "testFunction", line: 300)
        
        assertLogCaptured(
            .fatal,
            "Fault message",
            [
                "sentry.origin": SentryLog.Attribute(string: "auto.logging.swiftybeaver"),
                "swiftybeaver.level": SentryLog.Attribute(string: "6"),
                "swiftybeaver.thread": SentryLog.Attribute(string: "main"),
                "swiftybeaver.file": SentryLog.Attribute(string: "Test.swift"),
                "swiftybeaver.function": SentryLog.Attribute(string: "testFunction"),
                "swiftybeaver.line": SentryLog.Attribute(string: "300")
            ]
        )
        
        XCTAssertNil(result)
    }
    
    func testContextDictionary_WithAllSupportedTypes() {
        let context: [String: Any] = [
            "userId": "12345",                  // String
            "isActive": true,                   // Bool
            "errorCode": 500,                   // Int
            "amount": 99.99,                    // Double
            "temperature": Float(36.6),         // Float (converted to Double)
            "tags": ["production", "api", "v2"] // Array (unsupported, converted to String)
        ]
        let result = sut.send(.error, msg: "Payment failed", thread: "main", file: "Test.swift", function: "testFunction", line: 150, context: context)
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1)
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        // Verify all attribute types are preserved correctly
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.userId"]?.type, "string")
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.userId"]?.value as? String, "12345")
        
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.isActive"]?.type, "boolean")
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.isActive"]?.value as? Bool, true)
        
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.errorCode"]?.type, "integer")
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.errorCode"]?.value as? Int, 500)
        
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.amount"]?.type, "double")
        if let amountValue = capturedLog.attributes["swiftybeaver.context.amount"]?.value as? Double {
            XCTAssertEqual(amountValue, 99.99, accuracy: 0.001)
        } else {
            XCTFail("Amount value should be a Double")
        }
        
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.temperature"]?.type, "double")
        if let tempValue = capturedLog.attributes["swiftybeaver.context.temperature"]?.value as? Double {
            XCTAssertEqual(tempValue, 36.6, accuracy: 0.01)
        } else {
            XCTFail("Temperature value should be a Double")
        }
        
        // Verify unsupported type (array) is converted to string
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context.tags"]?.type, "string")
        let tagsValue = capturedLog.attributes["swiftybeaver.context.tags"]?.value as? String
        XCTAssertNotNil(tagsValue)
        XCTAssertTrue(tagsValue?.contains("production") ?? false, "Tags string should contain 'production'")
        XCTAssertTrue(tagsValue?.contains("api") ?? false, "Tags string should contain 'api'")
        XCTAssertTrue(tagsValue?.contains("v2") ?? false, "Tags string should contain 'v2'")
        
        XCTAssertNil(result)
    }
    
    func testContextNonDictionary_ConvertsToString() {
        let context = "simple string context"
        _ = sut.send(.info, msg: "Test message", thread: "main", file: "Test.swift", function: "testFunction", line: 10, context: context)
        
        let logs = fixture.batcher.addInvocations.invocations
        XCTAssertEqual(logs.count, 1)
        
        guard let capturedLog = logs.first else {
            XCTFail("No log captured")
            return
        }
        
        XCTAssertNotNil(capturedLog.attributes["swiftybeaver.context"])
        XCTAssertEqual(capturedLog.attributes["swiftybeaver.context"]?.value as? String, "simple string context")
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
