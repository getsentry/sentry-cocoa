@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// Tests for SPM log capture workarounds using dynamic dispatch.
/// These tests verify that the Objective-C methods can be called via perform(Selector:with:),
/// which is what the SPM extensions (SentryLob+SPM.swift) do internally.
final class SentryLogSPMTests: XCTestCase {
    
    private class Fixture {
        let hub: TestHub
        let client: TestClient
        let dateProvider: TestCurrentDateProvider
        let options: Options
        let scope: Scope
        let logOutput: TestLogOutput
        var oldDebug: Bool!
        var oldLevel: SentryLevel!
        var oldOutput: SentryLogOutput!
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLogSPMTests")
            options.enableLogs = true
            
            client = TestClient(options: options)!
            scope = Scope()
            hub = TestHub(client: client, andScope: scope)
            dateProvider = TestCurrentDateProvider()
            
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_627_846_800.123456))
            
            // Set up log capture for testing error messages
            oldDebug = SentrySDKLog.isDebug
            oldLevel = SentrySDKLog.diagnosticLevel
            oldOutput = SentrySDKLog.getOutput()
            logOutput = TestLogOutput()
            SentrySDKLog.setLogOutput(logOutput)
            SentrySDKLogSupport.configure(true, diagnosticLevel: .error)
        }
        
        func tearDown() {
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.tearDown()
        clearTestState()
    }
    
    // MARK: - SentryHub Tests
    
    func testHub_CaptureLog_ViaDispatcher() {
        // This test verifies that the dispatcher works correctly for captureLog.
        // This is what SentryLog+SPM.swift does internally in the capture(log:) extension method.
        
        let log = SentryLog(
            timestamp: fixture.dateProvider.date(),
            traceId: SentryId.empty,
            level: .info,
            body: "Test message via dispatcher",
            attributes: [
                "test_key": SentryLog.Attribute(string: "test_value"),
                "count": SentryLog.Attribute(integer: 42)
            ]
        )
        
        // Call using dispatcher - tests the actual implementation
        let result = CaptureLogDispatcher.captureLog(log, on: fixture.hub)
        
        // Verify success
        XCTAssertTrue(result)
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        
        let capturedLog = fixture.client.captureLogInvocations.invocations.last!.log
        XCTAssertEqual(capturedLog.level, .info)
        XCTAssertEqual(capturedLog.body, "Test message via dispatcher")
        XCTAssertEqual(capturedLog.attributes["test_key"]?.value as? String, "test_value")
        XCTAssertEqual(capturedLog.attributes["count"]?.value as? Int, 42)
    }
    
    func testHub_CaptureLogWithScope_ViaDispatcher() {
        // This test verifies that the dispatcher works correctly for captureLog:withScope:.
        // This is what SentryLog+SPM.swift does internally in the capture(log:scope:) extension method.
        
        let log = SentryLog(
            timestamp: fixture.dateProvider.date(),
            traceId: SentryId.empty,
            level: .error,
            body: "Test message with scope via dispatcher",
            attributes: [
                "severity": SentryLog.Attribute(string: "high")
            ]
        )
        
        let customScope = Scope()
        customScope.setTag(value: "test-value", key: "test-tag")
        
        // Call using dispatcher - tests the actual implementation
        let result = CaptureLogDispatcher.captureLog(log, withScope: fixture.scope, on: fixture.hub)
        
        // Verify success
        XCTAssertTrue(result)
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        
        let capturedLog = fixture.client.captureLogInvocations.invocations.last!.log
        XCTAssertEqual(capturedLog.level, .error)
        XCTAssertEqual(capturedLog.body, "Test message with scope via dispatcher")
        XCTAssertEqual(capturedLog.attributes["severity"]?.value as? String, "high")
    }
    
    // MARK: - SentryClient Tests
    
    func testClient_CaptureLog_ViaDispatcher() {
        // This test verifies that the dispatcher works correctly for client.captureLog:withScope:.
        // This is what SentryLog+SPM.swift does internally in the captureLog(_:withScope:) extension method.
        
        let log = SentryLog(
            timestamp: fixture.dateProvider.date(),
            traceId: SentryId.empty,
            level: .warn,
            body: "Test message via client dispatcher",
            attributes: [
                "priority": SentryLog.Attribute(string: "medium")
            ]
        )
        
        // Call using dispatcher - tests the actual implementation
        let result = CaptureLogDispatcher.captureLog(log, withScope: fixture.scope, on: fixture.client)
        
        // Verify success
        XCTAssertTrue(result)
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        
        let capturedLog = fixture.client.captureLogInvocations.invocations.last!.log
        XCTAssertEqual(capturedLog.level, .warn)
        XCTAssertEqual(capturedLog.body, "Test message via client dispatcher")
        XCTAssertEqual(capturedLog.attributes["priority"]?.value as? String, "medium")
    }
        
    // MARK: - SentryOptions Tests
    
    func testOptions_BeforeSendLog_ViaKVC() {
        // This test verifies that options.value(forKey:) and setValue(:forKey:) work correctly for beforeSendLog.
        // This is what SentryOptions+SPM.swift does internally in its beforeSendLog property getter/setter.
        
        let callback: (SentryLog) -> SentryLog? = { log in
            let modifiedLog = log
            modifiedLog.body = "Modified: \(log.body)"
            return modifiedLog
        }
        
        // Set using KVC - mimics SPM extension behavior
        fixture.options.setValue(callback, forKey: "beforeSendLogDynamic")
        
        // Get using KVC - mimics SPM extension behavior
        let retrievedCallback = fixture.options.value(forKey: "beforeSendLogDynamic") as? (SentryLog) -> SentryLog?
        
        XCTAssertNotNil(retrievedCallback)
        
        let originalLog = SentryLog(level: .info, body: "Original message")
        let modifiedLog = retrievedCallback?(originalLog)
        
        XCTAssertNotNil(modifiedLog)
        XCTAssertEqual(modifiedLog?.body, "Modified: Original message")
    }
    
    func testOptions_BeforeSendLog_CanDropLog() {
        let callback: (SentryLog) -> SentryLog? = { log in
            // Drop logs with "spam" in the body
            return log.body.contains("spam") ? nil : log
        }
        
        fixture.options.setValue(callback, forKey: "beforeSendLogDynamic")
        let retrievedCallback = fixture.options.value(forKey: "beforeSendLogDynamic") as? (SentryLog) -> SentryLog?
        
        let normalLog = SentryLog(level: .info, body: "Normal message")
        let spamLog = SentryLog(level: .info, body: "This is spam")
        
        XCTAssertNotNil(retrievedCallback?(normalLog))
        XCTAssertNil(retrievedCallback?(spamLog))
    }
    
    func testOptions_BeforeSendLog_CanFilterByLevel() {
        // Only allow error and fatal logs
        let callback: (SentryLog) -> SentryLog? = { log in
            return (log.level == .error || log.level == .fatal) ? log : nil
        }
        
        fixture.options.setValue(callback, forKey: "beforeSendLogDynamic")
        let retrievedCallback = fixture.options.value(forKey: "beforeSendLogDynamic") as? (SentryLog) -> SentryLog?
        
        let infoLog = SentryLog(level: .info, body: "Info message")
        let errorLog = SentryLog(level: .error, body: "Error message")
        let fatalLog = SentryLog(level: .fatal, body: "Fatal message")
        
        XCTAssertNil(retrievedCallback?(infoLog))
        XCTAssertNotNil(retrievedCallback?(errorLog))
        XCTAssertNotNil(retrievedCallback?(fatalLog))
    }
    
    func testOptions_BeforeSendLog_CanModifyAttributes() {
        let callback: (SentryLog) -> SentryLog? = { log in
            let modifiedLog = log
            var newAttributes = log.attributes
            newAttributes["processed"] = SentryLog.Attribute(boolean: true)
            modifiedLog.attributes = newAttributes
            return modifiedLog
        }
        
        fixture.options.setValue(callback, forKey: "beforeSendLogDynamic")
        let retrievedCallback = fixture.options.value(forKey: "beforeSendLogDynamic") as? (SentryLog) -> SentryLog?
        
        let log = SentryLog(
            level: .info,
            body: "Test message",
            attributes: ["original": SentryLog.Attribute(string: "value")]
        )
        
        let modifiedLog = retrievedCallback?(log)
        
        XCTAssertNotNil(modifiedLog)
        XCTAssertEqual(modifiedLog?.attributes.count, 2)
        XCTAssertEqual(modifiedLog?.attributes["original"]?.value as? String, "value")
        XCTAssertEqual(modifiedLog?.attributes["processed"]?.value as? Bool, true)
    }
    
    func testOptions_BeforeSendLog_CanBeCleared() {
        fixture.options.setValue({ (log: SentryLog) in log }, forKey: "beforeSendLogDynamic")
        XCTAssertNotNil(fixture.options.value(forKey: "beforeSendLogDynamic"))
        
        fixture.options.setValue(nil, forKey: "beforeSendLogDynamic")
        
        XCTAssertNil(fixture.options.value(forKey: "beforeSendLogDynamic"))
    }
    
    // MARK: - CaptureLogDispatcher Error Handling Tests
    
    func testDispatcher_CaptureLog_FailsWhenSelectorNotAvailable() {
        // Test with a plain NSObject that doesn't implement captureLog methods
        let plainObject = NSObject()
        let log = SentryLog(level: .info, body: "Test message")
        
        let result = CaptureLogDispatcher.captureLog(log, on: plainObject)
        
        XCTAssertFalse(result)
        XCTAssertTrue(fixture.logOutput.loggedMessages.contains { message in
            message.contains("NSObject") &&
            message.contains("does not respond to captureLog(_:)")
        })
    }
    
    func testDispatcher_CaptureLogWithScope_FailsWhenSelectorNotAvailable() {
        // Test with a plain NSObject that doesn't implement captureLog methods
        let plainObject = NSObject()
        let log = SentryLog(level: .info, body: "Test message")
        let scope = Scope()
        
        let result = CaptureLogDispatcher.captureLog(log, withScope: scope, on: plainObject)
        
        XCTAssertFalse(result)
        XCTAssertTrue(fixture.logOutput.loggedMessages.contains { message in
            message.contains("NSObject") &&
            message.contains("does not respond to captureLog(_:withScope:)")
        })
    }
    
}
