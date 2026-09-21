#if SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

final class SentryKSCrashReplayCheckpointTests: XCTestCase {
    private var checkpointURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        checkpointURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kscrash-replay-checkpoint-\(UUID().uuidString)")
        sentrykscrash_attachments_setScreenshotWriter(nil)
        sentrykscrash_attachments_setViewHierarchyWriter(nil)
        sentrykscrash_attachments_setEnabled(false, nil)
        sentrykscrash_attachments_setSidecarPathProvider(nil)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: checkpointURL.path) {
            try FileManager.default.removeItem(at: checkpointURL)
        }
        try super.tearDownWithError()
    }

    func testDidWriteReport_whenFatalCrash_shouldWriteReplayCheckpoint() throws {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 0xAB)

        // -- Assert --
        var output = SentryCrashReplay()
        XCTAssertTrue(sentrySessionReplaySync_readInfo(&output, checkpointURL.path))
        XCTAssertEqual(output.segmentId, UInt32(7))
        XCTAssertEqual(output.lastSegmentEnd, 123.5)
        XCTAssertEqual(output.replayType, UInt32(1))
    }

    func testDidWriteReport_whenNoAttachmentWriters_shouldStillWriteCheckpoint() throws {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 2)
        sentrySessionReplaySync_updateInfo(3, 42)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 1)

        // -- Assert --
        var output = SentryCrashReplay()
        XCTAssertTrue(sentrySessionReplaySync_readInfo(&output, checkpointURL.path))
        XCTAssertEqual(output.segmentId, UInt32(3))
        XCTAssertEqual(output.lastSegmentEnd, 42)
        XCTAssertEqual(output.replayType, UInt32(2))
    }

    func testDidWriteReport_whenNotFatal_shouldNotWriteCheckpoint() {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(false, false, false, 1)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: checkpointURL.path))
    }

    func testDidWriteReport_whenCleanExit_shouldNotWriteCheckpoint() {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, true, false, 1)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: checkpointURL.path))
    }

    func testDidWriteReport_whenCrashedDuringExceptionHandling_shouldNotWriteCheckpoint() {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, true, 1)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: checkpointURL.path))
    }

    func testDidWriteReport_whenReportIDInvalid_shouldNotWriteCheckpoint() {
        // -- Arrange --
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, 0)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: checkpointURL.path))
    }
}
#endif
