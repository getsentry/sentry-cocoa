#if SDK_V10
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

private var saveTransactionCallCount = 0
private let testSaveTransaction: @convention(c) () -> Void = {
    saveTransactionCallCount += 1
}

final class SentryKSCrashSaveTransactionTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        saveTransactionCallCount = 0
        sentrykscrash_setSaveTransaction(nil)
        sentrykscrash_attachments_setScreenshotWriter(nil)
        sentrykscrash_attachments_setViewHierarchyWriter(nil)
        sentrykscrash_attachments_setEnabled(false, nil)
        sentrykscrash_attachments_setSidecarPathProvider(nil)
    }

    override func tearDownWithError() throws {
        sentrykscrash_setSaveTransaction(nil)
        saveTransactionCallCount = 0
        try super.tearDownWithError()
    }

    func testDidWriteReport_whenFatalCrash_shouldInvokeSaveTransaction() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 0xAB)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 1)
    }

    func testDidWriteReport_whenNotFatal_shouldNotInvokeSaveTransaction() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(false, false, false, 1)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 0)
    }

    func testDidWriteReport_whenCleanExit_shouldNotInvokeSaveTransaction() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, true, false, 1)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 0)
    }

    func testDidWriteReport_whenCrashedDuringExceptionHandling_shouldNotInvokeSaveTransaction() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, true, 1)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 0)
    }

    func testDidWriteReport_whenReportIDInvalid_shouldNotInvokeSaveTransaction() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 0)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 0)
    }

    func testDidWriteReport_whenNoCallback_shouldNotCrash() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(nil)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 1)

        // -- Assert --
        XCTAssertEqual(saveTransactionCallCount, 0)
    }

    func testHasSaveTransaction_whenCallbackSet_shouldReturnTrue() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)

        // -- Act --
        let hasCallback = sentrykscrash_hasSaveTransaction()

        // -- Assert --
        XCTAssertTrue(hasCallback)
    }

    func testHasSaveTransaction_whenCallbackCleared_shouldReturnFalse() {
        // -- Arrange --
        sentrykscrash_setSaveTransaction(testSaveTransaction)
        sentrykscrash_setSaveTransaction(nil)

        // -- Act --
        let hasCallback = sentrykscrash_hasSaveTransaction()

        // -- Assert --
        XCTAssertFalse(hasCallback)
    }
}
#endif
