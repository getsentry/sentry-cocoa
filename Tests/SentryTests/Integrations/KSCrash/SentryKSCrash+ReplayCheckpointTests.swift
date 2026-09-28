#if SDK_V10
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

private enum ReplayCheckpointTestRoot {
    nonisolated(unsafe) static var installDir: URL?
    nonisolated(unsafe) static var checkpointPath = ""
    nonisolated(unsafe) static var writerRan = false
    nonisolated(unsafe) static var writerSawCheckpoint = false

    static func markerURL(installDir: URL, reportID: Int64) -> URL {
        installDir
            .appendingPathComponent("Sidecars", isDirectory: true)
            .appendingPathComponent("SentryAttachments", isDirectory: true)
            .appendingPathComponent(String(format: "%016llx.ksscr", UInt64(bitPattern: reportID)))
    }
}

private let testScreenshotWriterChecksCheckpoint: @convention(c) (UnsafePointer<CChar>) -> Void = { _ in
    ReplayCheckpointTestRoot.writerRan = true
    ReplayCheckpointTestRoot.writerSawCheckpoint = FileManager.default.fileExists(
        atPath: ReplayCheckpointTestRoot.checkpointPath
    )
}

final class SentryKSCrashReplayCheckpointTests: XCTestCase {
    private var checkpointURL: URL!
    private var installDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        checkpointURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kscrash-replay-checkpoint-\(UUID().uuidString)")
        installDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kscrash-replay-checkpoint-install-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
        ReplayCheckpointTestRoot.installDir = installDir
        ReplayCheckpointTestRoot.checkpointPath = checkpointURL.path
        ReplayCheckpointTestRoot.writerRan = false
        ReplayCheckpointTestRoot.writerSawCheckpoint = false
        sentrykscrash_attachments_setScreenshotWriter(nil)
        sentrykscrash_attachments_setViewHierarchyWriter(nil)
        sentrykscrash_attachments_setEnabled(false, nil)
        sentrykscrash_attachments_setSidecarPathProvider(nil)
        sentrykscrash_setSaveTransaction(nil)
    }

    override func tearDownWithError() throws {
        sentrykscrash_attachments_setScreenshotWriter(nil)
        sentrykscrash_attachments_setViewHierarchyWriter(nil)
        sentrykscrash_attachments_setEnabled(false, nil)
        sentrykscrash_attachments_setSidecarPathProvider(nil)
        ReplayCheckpointTestRoot.installDir = nil
        ReplayCheckpointTestRoot.checkpointPath = ""
        ReplayCheckpointTestRoot.writerRan = false
        ReplayCheckpointTestRoot.writerSawCheckpoint = false
        if FileManager.default.fileExists(atPath: checkpointURL.path) {
            try FileManager.default.removeItem(at: checkpointURL)
        }
        if FileManager.default.fileExists(atPath: installDir.path) {
            try FileManager.default.removeItem(at: installDir)
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

    func testDidWriteReport_whenScreenshotWriterRuns_shouldHaveWrittenCheckpointFirst() throws {
        // -- Arrange --
        let reportID: Int64 = 0xAB
        sentrySessionReplaySync_start(checkpointURL.path, 1)
        sentrySessionReplaySync_updateInfo(7, 123.5)
        sentrykscrash_attachments_setEnabled(true, nil)
        sentrykscrash_attachments_setScreenshotWriter(testScreenshotWriterChecksCheckpoint)
        sentrykscrash_attachments_setSidecarPathProvider { _, id, pathBuffer, length in
            guard let pathBuffer, let root = ReplayCheckpointTestRoot.installDir else {
                return false
            }
            let path = ReplayCheckpointTestRoot.markerURL(installDir: root, reportID: id).path
            return path.withCString { source in
                let needed = strlen(source) + 1
                guard needed <= length else { return false }
                memcpy(pathBuffer, source, needed)
                return true
            }
        }

        // -- Act --
        sentrykscrash_test_invokeDidWriteReport(true, false, false, reportID)

        // -- Assert --
        XCTAssertTrue(ReplayCheckpointTestRoot.writerRan)
        XCTAssertTrue(ReplayCheckpointTestRoot.writerSawCheckpoint)
        var output = SentryCrashReplay()
        XCTAssertTrue(sentrySessionReplaySync_readInfo(&output, checkpointURL.path))
        XCTAssertEqual(output.segmentId, UInt32(7))
        XCTAssertEqual(output.lastSegmentEnd, 123.5)
        XCTAssertEqual(output.replayType, UInt32(1))
    }
}
#endif
