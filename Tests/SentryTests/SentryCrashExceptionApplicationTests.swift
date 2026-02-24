@_spi(Private) @testable import Sentry
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
