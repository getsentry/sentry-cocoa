@_spi(Private) import Sentry
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

        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
    }
    
    func testSwizzleNSApplicationCrashOnException_classMethod() throws {
        let selector = NSSelectorFromString("_crashOnException:")
        try XCTSkipUnless(
            NSApplication.responds(to: selector),
            "_crashOnException: class method not available on this macOS version"
        )

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }

        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()

        // Call the class method +[NSApplication _crashOnException:].
        // In tests, SentrySWCallOriginal is skipped so this won't abort().
        NSApplication.perform(selector, with: uncaughtInternalInconsistencyException)

        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
    }

    func testSwizzleNSApplicationCrashOnException_calledMultipleTimes_classMethodCapturesOnce() throws {
        let selector = NSSelectorFromString("_crashOnException:")
        try XCTSkipUnless(
            NSApplication.responds(to: selector),
            "_crashOnException: class method not available on this macOS version"
        )

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
            uncaughtExceptionHandlerCallCount = 0
        }

        uncaughtExceptionHandlerCallCount = 0
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        // Simulate multiple SDK starts — the class method swizzle should not stack.
        SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()
        SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()

        NSApplication.perform(selector, with: uncaughtInternalInconsistencyException)

        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
        XCTAssertEqual(uncaughtExceptionHandlerCallCount, 1, "Handler should fire exactly once, not stack on repeated SDK starts")
    }

    func testSwizzleNSApplicationCrashOnException_instanceMethod() throws {
        let selector = NSSelectorFromString("_crashOnException:")
        try XCTSkipUnless(
            NSApplication.shared.responds(to: selector),
            "_crashOnException: instance method not available on this macOS version"
        )

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }

        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()

        // Call the instance method -[NSApp _crashOnException:].
        // In tests, SentrySWCallOriginal is skipped so this won't abort().
        NSApplication.shared.perform(selector, with: uncaughtInternalInconsistencyException)

        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
    }

#endif // os(macOS)

}

// We need to declare this on the file level because otherwise we get the error:
// A C function pointer cannot be formed from a closure that captures context.
var wasUncaughtExceptionHandlerCalled = false
var uncaughtExceptionHandlerCallCount = 0
func uncaughtExceptionHandler(exception: NSException) {
    XCTAssertEqual(uncaughtInternalInconsistencyException.name, exception.name)
    XCTAssertEqual(uncaughtInternalInconsistencyException.reason, exception.reason)
    wasUncaughtExceptionHandlerCalled = true
    uncaughtExceptionHandlerCallCount += 1
}

let uncaughtInternalInconsistencyException = NSException(name: .internalInconsistencyException, reason: "reason", userInfo: nil)
