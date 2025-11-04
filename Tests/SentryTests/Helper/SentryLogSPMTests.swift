@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// Tests for SPM log workarounds using dynamic dispatch.
final class SentryLogSPMTests: XCTestCase {
    
    private class Fixture {
        let options: Options
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryLogSPMTests")
            options.enableLogs = true
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
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
    
    func testOptions_BeforeSendLog_ViaKVC_DirectProperty() {
        // Test if we can use "beforeSendLog" directly via KVC instead of "beforeSendLogDynamic"
        // This would work in non-SPM builds but not in SPM builds where the property isn't declared
        let callback: (SentryLog) -> SentryLog? = { log in
            let modifiedLog = log
            modifiedLog.body = "Modified: \(log.body)"
            return modifiedLog
        }
        
        // Try to set using "beforeSendLog" directly
        fixture.options.setValue(callback, forKey: "beforeSendLog")
        
        // Try to get using "beforeSendLog" directly
        let retrievedCallback = fixture.options.value(forKey: "beforeSendLog") as? (SentryLog) -> SentryLog?
        
        // In SPM builds, this will be nil because the property doesn't exist
        // In non-SPM builds, this should work because the property is auto-synthesized
        #if SWIFT_PACKAGE
        XCTAssertNil(retrievedCallback, "In SPM builds, 'beforeSendLog' property doesn't exist, so KVC should fail")
        #else
        XCTAssertNotNil(retrievedCallback, "In non-SPM builds, 'beforeSendLog' property exists and should work via KVC")
        
        if let retrievedCallback = retrievedCallback {
            let originalLog = SentryLog(level: .info, body: "Original message")
            let modifiedLog = retrievedCallback(originalLog)
            XCTAssertNotNil(modifiedLog)
            XCTAssertEqual(modifiedLog?.body, "Modified: Original message")
        }
        #endif
    }
}
