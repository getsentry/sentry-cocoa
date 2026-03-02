@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if os(macOS)

private var exceptionHandlerCallCount = 0
private func countingExceptionHandler(exception: NSException) {
    exceptionHandlerCallCount += 1
}

class SentryNSExceptionCaptureHelperTests: XCTestCase {

    override func tearDown() {
        super.tearDown()

        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = nil
        exceptionHandlerCallCount = 0

        clearTestState()
        resetUserDefaults()
        UserDefaults.standard.removeObject(forKey: "NSApplicationCrashOnExceptions")
    }

    func testReportExceptionCallsHandler() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = countingExceptionHandler

        SentryNSExceptionCaptureHelper.report(uncaughtInternalInconsistencyException)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        XCTAssertEqual(exceptionHandlerCallCount, 1)
    }

    func testReportExceptionWithoutUncaughtExceptionHandler() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = nil

        SentryNSExceptionCaptureHelper.report(uncaughtInternalInconsistencyException)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        XCTAssertEqual(exceptionHandlerCallCount, 0)
    }

    func testCrashOnException_directCall_capturesException() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = countingExceptionHandler

        SentryNSExceptionCaptureHelper.crash(on: uncaughtInternalInconsistencyException)

        XCTAssertEqual(exceptionHandlerCallCount, 1)
    }

    func testCrashOnException_calledDuringReportException_doesNotDuplicate() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = countingExceptionHandler

        // Simulate the flow: reportException: captures, then [super reportException:]
        // internally calls _crashOnException: (when NSApplicationCrashOnExceptions is YES).
        SentryNSExceptionCaptureHelper.report(uncaughtInternalInconsistencyException)

        // This simulates _crashOnException: being called by [super reportException:]
        SentryNSExceptionCaptureHelper.crash(on: uncaughtInternalInconsistencyException)

        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        XCTAssertEqual(exceptionHandlerCallCount, 1)
    }

    func testCrashOnException_afterReportExceptionFinishes_capturesNormally() {
        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter
        crashReporter.uncaughtExceptionHandler = countingExceptionHandler

        // First: a full reportException: cycle
        SentryNSExceptionCaptureHelper.report(uncaughtInternalInconsistencyException)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // Then: a direct _crashOnException: call (separate AppKit code path)
        SentryNSExceptionCaptureHelper.crash(on: uncaughtInternalInconsistencyException)

        XCTAssertEqual(exceptionHandlerCallCount, 2)
    }
}

#endif // os(macOS)
