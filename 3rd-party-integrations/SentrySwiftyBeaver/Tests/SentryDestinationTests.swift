import Sentry
@testable import SentrySwiftyBeaver
import SwiftyBeaver
import XCTest

final class SentryDestinationTests: XCTestCase {
    
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
    
    func testVerboseMapsToTrace() throws {
        let sut = SentryDestination()
        let result = sut.send(.verbose, msg: "Verbose message", thread: "main", file: "Test.swift", function: "testFunction", line: 42)
        
        XCTAssertEqual(capturedLogs.count, 1, "Expected exactly one log to be captured")
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .trace)
        XCTAssertEqual(log.body, "Verbose message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "0")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "42")
        
        XCTAssertNil(result)
    }
    
    func testDebugMapsToDebug() throws {
        let sut = SentryDestination()
        let result = sut.send(.debug, msg: "Debug message", thread: "main", file: "Test.swift", function: "testFunction", line: 50)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .debug)
        XCTAssertEqual(log.body, "Debug message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "1")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "50")
        
        XCTAssertNil(result)
    }
    
    func testInfoMapsToInfo() throws {
        let sut = SentryDestination()
        let result = sut.send(.info, msg: "Info message", thread: "main", file: "Test.swift", function: "testFunction", line: 100)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.body, "Info message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "2")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "100")
        
        XCTAssertNil(result)
    }
    
    func testWarningMapsToWarn() throws {
        let sut = SentryDestination()
        let result = sut.send(.warning, msg: "Warning message", thread: "main", file: "Test.swift", function: "testFunction", line: 75)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .warn)
        XCTAssertEqual(log.body, "Warning message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "3")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "75")
        
        XCTAssertNil(result)
    }
    
    func testErrorMapsToError() throws {
        let sut = SentryDestination()
        let result = sut.send(.error, msg: "Error message", thread: "main", file: "Test.swift", function: "testFunction", line: 200)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .error)
        XCTAssertEqual(log.body, "Error message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "4")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "200")
        
        XCTAssertNil(result)
    }
    
    func testCriticalMapsToFatal() throws {
        let sut = SentryDestination()
        let result = sut.send(.critical, msg: "Critical message", thread: "main", file: "Test.swift", function: "testFunction", line: 250)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .fatal)
        XCTAssertEqual(log.body, "Critical message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "5")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "250")
        
        XCTAssertNil(result)
    }
    
    func testFaultMapsToFatal() throws {
        let sut = SentryDestination()
        let result = sut.send(.fault, msg: "Fault message", thread: "main", file: "Test.swift", function: "testFunction", line: 300)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(log.level, .fatal)
        XCTAssertEqual(log.body, "Fault message")
        XCTAssertEqual(log.attributes["sentry.origin"]?.value as? String, "auto.logging.swiftybeaver")
        XCTAssertEqual(log.attributes["swiftybeaver.level"]?.value as? String, "6")
        XCTAssertEqual(log.attributes["swiftybeaver.thread"]?.value as? String, "main")
        XCTAssertEqual(log.attributes["swiftybeaver.file"]?.value as? String, "Test.swift")
        XCTAssertEqual(log.attributes["swiftybeaver.function"]?.value as? String, "testFunction")
        XCTAssertEqual(log.attributes["swiftybeaver.line"]?.value as? String, "300")
        
        XCTAssertNil(result)
    }
    
    func testContextDictionary_WithAllSupportedTypes() throws {
        let sut = SentryDestination()
        let context: [String: Any] = [
            "userId": "12345",                  // String
            "isActive": true,                   // Bool
            "errorCode": 500,                   // Int
            "amount": 99.99,                    // Double
            "temperature": Float(36.6),         // Float (converted to Double)
            "tags": ["production", "api", "v2"] // Array (unsupported, converted to String)
        ]
        let result = sut.send(.error, msg: "Payment failed", thread: "main", file: "Test.swift", function: "testFunction", line: 150, context: context)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        
        // Verify all attribute types are preserved correctly
        XCTAssertEqual(log.attributes["swiftybeaver.context.userId"]?.type, "string")
        XCTAssertEqual(log.attributes["swiftybeaver.context.userId"]?.value as? String, "12345")
        
        XCTAssertEqual(log.attributes["swiftybeaver.context.isActive"]?.type, "boolean")
        XCTAssertEqual(log.attributes["swiftybeaver.context.isActive"]?.value as? Bool, true)
        
        XCTAssertEqual(log.attributes["swiftybeaver.context.errorCode"]?.type, "integer")
        XCTAssertEqual(log.attributes["swiftybeaver.context.errorCode"]?.value as? Int, 500)
        
        XCTAssertEqual(log.attributes["swiftybeaver.context.amount"]?.type, "double")
        if let amountValue = log.attributes["swiftybeaver.context.amount"]?.value as? Double {
            XCTAssertEqual(amountValue, 99.99, accuracy: 0.001)
        } else {
            XCTFail("Amount value should be a Double")
        }
        
        XCTAssertEqual(log.attributes["swiftybeaver.context.temperature"]?.type, "double")
        if let tempValue = log.attributes["swiftybeaver.context.temperature"]?.value as? Double {
            XCTAssertEqual(tempValue, 36.6, accuracy: 0.01)
        } else {
            XCTFail("Temperature value should be a Double")
        }
        
        // Verify unsupported type (array) is converted to string
        XCTAssertEqual(log.attributes["swiftybeaver.context.tags"]?.type, "string")
        let tagsValue = log.attributes["swiftybeaver.context.tags"]?.value as? String
        XCTAssertNotNil(tagsValue)
        XCTAssertTrue(tagsValue?.contains("production") ?? false, "Tags string should contain 'production'")
        XCTAssertTrue(tagsValue?.contains("api") ?? false, "Tags string should contain 'api'")
        XCTAssertTrue(tagsValue?.contains("v2") ?? false, "Tags string should contain 'v2'")
        
        XCTAssertNil(result)
    }
    
    func testContextNonDictionary_ConvertsToString() throws {
        let sut = SentryDestination()
        let context = "simple string context"
        _ = sut.send(.info, msg: "Test message", thread: "main", file: "Test.swift", function: "testFunction", line: 10, context: context)
        
        XCTAssertEqual(capturedLogs.count, 1)
        let log = try XCTUnwrap(capturedLogs.first)
        
        XCTAssertNotNil(log.attributes["swiftybeaver.context"])
        XCTAssertEqual(log.attributes["swiftybeaver.context"]?.value as? String, "simple string context")
    }
}
