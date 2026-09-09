#if SDK_V10
@_spi(Private) @testable import Sentry
import XCTest

#if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
import AppKit

private var capturedNSExceptions: [NSException] = []

private func captureNSException(_ exception: NSException) {
    capturedNSExceptions.append(exception)
}

final class SentryKSCrashNSExceptionTests: XCTestCase {
    private var handlerOwner = NSObject()

    override func setUp() {
        super.setUp()
        handlerOwner = NSObject()
        capturedNSExceptions = []
        SentryNSExceptionCaptureHelper.setUncaughtExceptionHandler(
            captureNSException,
            owner: handlerOwner
        )
    }

    override func tearDown() {
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()
        SentryNSExceptionCaptureHelper.clearUncaughtExceptionHandler(forOwner: handlerOwner)
        UserDefaults.standard.removeObject(forKey: "NSApplicationCrashOnExceptions")
        capturedNSExceptions = []
        super.tearDown()
    }

    func testReportException_whenHandlerInstalled_shouldForwardException() throws {
        // -- Arrange --
        let exception = makeException(scenario: "report-exception")

        // -- Act --
        SentryNSExceptionCaptureHelper.report(exception)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // -- Assert --
        let capturedException = try XCTUnwrap(capturedNSExceptions.first)
        XCTAssertIdentical(capturedException, exception)
        XCTAssertEqual(capturedNSExceptions.count, 1)
    }

    func testCrashOnException_whenCalledDuringReportException_shouldNotDuplicate() {
        // -- Arrange --
        let exception = makeException(scenario: "deduplicate")

        // -- Act --
        SentryNSExceptionCaptureHelper.report(exception)
        SentryNSExceptionCaptureHelper.crash(on: exception)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // -- Assert --
        XCTAssertEqual(capturedNSExceptions.count, 1)
    }

    func testCrashOnException_whenReportExceptionFinished_shouldForwardAgain() {
        // -- Arrange --
        let exception = makeException(scenario: "separate-appkit-path")
        SentryNSExceptionCaptureHelper.report(exception)
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // -- Act --
        SentryNSExceptionCaptureHelper.crash(on: exception)

        // -- Assert --
        XCTAssertEqual(capturedNSExceptions.count, 2)
    }

    func testClearHandler_whenOwnedByDifferentIntegration_shouldKeepCurrentHandler() {
        // -- Arrange --
        let previousOwner = handlerOwner
        let currentOwner = NSObject()
        handlerOwner = currentOwner
        SentryNSExceptionCaptureHelper.setUncaughtExceptionHandler(
            captureNSException,
            owner: currentOwner
        )

        // -- Act --
        SentryNSExceptionCaptureHelper.clearUncaughtExceptionHandler(forOwner: previousOwner)
        SentryNSExceptionCaptureHelper.report(makeException(scenario: "reinitialized"))
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // -- Assert --
        XCTAssertEqual(capturedNSExceptions.count, 1)
    }

    func testClearHandler_whenOwnedByCurrentIntegration_shouldStopForwarding() {
        // -- Act --
        SentryNSExceptionCaptureHelper.clearUncaughtExceptionHandler(forOwner: handlerOwner)
        SentryNSExceptionCaptureHelper.report(makeException(scenario: "closed"))
        SentryNSExceptionCaptureHelper.reportExceptionDidFinish()

        // -- Assert --
        XCTAssertTrue(capturedNSExceptions.isEmpty)
    }

    func testSwizzledReportException_shouldForwardException() throws {
        // -- Arrange --
        let exception = makeException(scenario: "swizzled-report-exception")
        SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")

        // -- Act --
        NSApplication.shared.reportException(exception)

        // -- Assert --
        let capturedException = try XCTUnwrap(capturedNSExceptions.first)
        XCTAssertIdentical(capturedException, exception)
        XCTAssertEqual(capturedNSExceptions.count, 1)
    }

    private func makeException(scenario: String) -> NSException {
        NSException(
            name: NSExceptionName("CrashE2ENSExceptionSubclass"),
            reason: "Crash E2E uncaught NSException subclass",
            userInfo: ["scenario": scenario]
        )
    }
}
#endif
#endif
