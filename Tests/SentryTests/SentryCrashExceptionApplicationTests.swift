@testable import Sentry
import SentryTestUtils
import XCTest

#if os(macOS)

class SentryCrashExceptionApplicationHelperTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        
        clearTestState()
        resetUserDefaults()
        UserDefaults.standard.removeObject(forKey: "NSApplicationCrashOnExceptions")
    }
    
    func testCrashOnException() throws {
        // Arrange
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        let exception = NSException(name: NSExceptionName("TestException"), reason: "Test Reason", userInfo: nil)
        
        // Act
        SentryCrashExceptionApplicationHelper._crash(on: exception)
        
        // Assert
        let testClient = try XCTUnwrap(SentrySDK.currentHub().getClient() as? TestClient)
        XCTAssertEqual(1, testClient.captureExceptionWithScopeInvocations.count)
        XCTAssertEqual(exception.name, testClient.captureExceptionWithScopeInvocations.first?.exception.name)
        XCTAssertEqual(exception.reason, testClient.captureExceptionWithScopeInvocations.first?.exception.reason)
    }
    
    func testReportExceptionWithUncaughtExceptionHandler() {
        // Arrange
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
            UserDefaults.standard.removeObject(forKey: "NSApplicationCrashOnExceptions")
        }
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler
        
        // Act
        SentryCrashExceptionApplicationHelper.report(uncaughtInternalInconsistencyException)
        
        // Assert
        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
    }
    
    func testReportExceptionWithoutUncaughtExceptionHandler() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = nil
        
        SentryCrashExceptionApplicationHelper.report(uncaughtInternalInconsistencyException)
        
        XCTAssertFalse(wasUncaughtExceptionHandlerCalled)
    }
}

#endif // os(macOS)
