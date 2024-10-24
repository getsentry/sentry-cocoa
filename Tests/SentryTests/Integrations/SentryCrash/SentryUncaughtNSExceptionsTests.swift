import Sentry
import SentryTestUtils
import XCTest

final class SentryUncaughtNSExceptionsTests: XCTestCase {

#if os(macOS)
    func testConfigure_SetsUserDefault() throws {
        defer { resetUserDefaults() }
        
        SentryUncaughtNSExceptions.configureCrashOnExceptions()
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "NSApplicationCrashOnExceptions"))
    }
    
    func testSwizzleNSApplicationReportException() throws {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        
        defer {
            resetUserDefaults()
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler
        
        SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
        
        // We have to set the flat to false, cause otherwise we would crash
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")
        NSApplication.shared.reportException(uncaughtInternalInconsistencyException)
    }
    
    func testCapture_ForwardsException() throws {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        
        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler
      
        SentryUncaughtNSExceptions.capture(uncaughtInternalInconsistencyException)
    }
    
    func testCapture_NoUncaughtExceptionHandler() throws {
        defer { wasUncaughtExceptionHandlerCalled = false }
        
        SentryUncaughtNSExceptions.capture(uncaughtInternalInconsistencyException)
        
        XCTAssertFalse(wasUncaughtExceptionHandlerCalled)
    }
    
    func testCapture_ExceptionIsNil() throws {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        
        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        SentryUncaughtNSExceptions.capture(nil)
        XCTAssertFalse(wasUncaughtExceptionHandlerCalled)
    }
#endif // os(macOS)

}

// We need to declare this on the file level because otherwise we get the error:
// A C function pointer cannot be formed from a closure that captures context.
var wasUncaughtExceptionHandlerCalled = false
func uncaughtExceptionHandler(exception: NSException) {
    XCTAssertEqual(uncaughtInternalInconsistencyException.name, exception.name)
    XCTAssertEqual(uncaughtInternalInconsistencyException.reason, exception.reason)
    wasUncaughtExceptionHandlerCalled = true
}

let uncaughtInternalInconsistencyException = NSException(name: .internalInconsistencyException, reason: "reason", userInfo: nil)
