#if SDK_V10
@_spi(Private) @testable import Sentry
internal import KSCrashRecordingCore
import Foundation
import XCTest

private enum AttachmentsMonitorTestRoot {
    nonisolated(unsafe) static var installDir: URL?
}

private nonisolated(unsafe) var testPNGBytes = Data()
private nonisolated(unsafe) var testWriterCalls = 0

private let testWritePNG: @convention(c) (UnsafePointer<CChar>) -> Void = { path in
    let url = URL(fileURLWithPath: String(cString: path)).appendingPathComponent("screenshot.png")
    FileManager.default.createFile(atPath: url.path, contents: testPNGBytes)
}

private let testWriteNothing: @convention(c) (UnsafePointer<CChar>) -> Void = { _ in }

private let testCountWrites: @convention(c) (UnsafePointer<CChar>) -> Void = { _ in
    testWriterCalls += 1
}

private let testWriteArbitraryFiles: @convention(c) (UnsafePointer<CChar>) -> Void = { path in
    let dir = URL(fileURLWithPath: String(cString: path))
    FileManager.default.createFile(
        atPath: dir.appendingPathComponent("screenshot.png").path,
        contents: Data("shot".utf8)
    )
    FileManager.default.createFile(
        atPath: dir.appendingPathComponent("view-hierarchy.json").path,
        contents: Data("hierarchy".utf8)
    )
}

final class SentryKSCrashAttachmentsMonitorTests: XCTestCase {
    private static let pngBytes: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
    ]

    private var installDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        installDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kscrash-screenshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
        AttachmentsMonitorTestRoot.installDir = installDir
        testPNGBytes = Data(Self.pngBytes)
        testWriterCalls = 0
    }

    override func tearDownWithError() throws {
        sentrykscrash_attachments_setScreenshotWriter(nil)
        sentrykscrash_attachments_setEnabled(false)
        AttachmentsMonitorTestRoot.installDir = nil
        if let installDir, FileManager.default.fileExists(atPath: installDir.path) {
            try FileManager.default.removeItem(at: installDir)
        }
        try super.tearDownWithError()
    }

    func testHandleDidWriteReport_whenProviderWritesPNG_shouldWritePayloadAndMarker() throws {
        // -- Arrange --
        let reportID: Int64 = 0xAB
        let monitor = try makeMonitor(reportID: reportID)
        monitor.setScreenshotWriter(testWritePNG)

        // -- Act --
        sentrykscrash_attachments_capture(reportID)

        // -- Assert --
        let screenshotURL = payloadDirectory(reportID: reportID).appendingPathComponent("screenshot.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: screenshotURL.path))
        XCTAssertEqual(try Data(contentsOf: screenshotURL), Data(Self.pngBytes))
        XCTAssertTrue(SentryKSCrash.AttachmentsMonitor.Marker.isValid(at: markerURL(reportID: reportID)))
    }

    func testHandleDidWriteReport_whenProviderWritesNothing_shouldNotWriteMarker() throws {
        // -- Arrange --
        let reportID: Int64 = 1
        let monitor = try makeMonitor(reportID: reportID)
        monitor.setScreenshotWriter(testWriteNothing)

        // -- Act --
        sentrykscrash_attachments_capture(reportID)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL(reportID: reportID).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: payloadDirectory(reportID: reportID).path))
    }

    func testHandleDidWriteReport_whenDisabled_shouldNotCapture() throws {
        // -- Arrange --
        let reportID: Int64 = 1
        let monitor = try makeMonitor(reportID: reportID)
        monitor.enabled = false
        monitor.setScreenshotWriter(testCountWrites)

        // -- Act --
        sentrykscrash_attachments_capture(reportID)

        // -- Assert --
        XCTAssertEqual(testWriterCalls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL(reportID: reportID).path))
    }

    func testStitchedReport_whenMarkerAndPNGExist_shouldInjectAttachmentPath() throws {
        // -- Arrange --
        let reportID: Int64 = 0xCD
        let monitor = try makeMonitor(reportID: reportID)
        monitor.setScreenshotWriter(testWritePNG)
        sentrykscrash_attachments_capture(reportID)
        let original = ["report": ["id": "1"]] as NSDictionary

        // -- Act --
        let result = stitchedReport(monitor, report: original, reportID: reportID, scope: KSCrashSidecarScopeReport)

        // -- Assert --
        let attachments = try XCTUnwrap(result["attachments"] as? [String])
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(
            URL(fileURLWithPath: try XCTUnwrap(attachments.first)).resolvingSymlinksInPath().path,
            payloadDirectory(reportID: reportID).appendingPathComponent("screenshot.png").resolvingSymlinksInPath().path
        )
        XCTAssertEqual(result["report"] as? [String: String], ["id": "1"])
    }

    func testStitchedReport_whenPayloadHasArbitraryFiles_shouldInjectAllPaths() throws {
        // -- Arrange --
        let reportID: Int64 = 0xEF
        let monitor = try makeMonitor(reportID: reportID)
        monitor.setScreenshotWriter(testWriteArbitraryFiles)
        sentrykscrash_attachments_capture(reportID)
        let original = ["report": ["id": "1"]] as NSDictionary

        // -- Act --
        let result = stitchedReport(monitor, report: original, reportID: reportID, scope: KSCrashSidecarScopeReport)

        // -- Assert --
        let attachments = try XCTUnwrap(result["attachments"] as? [String])
        let names = Set(attachments.map { URL(fileURLWithPath: $0).lastPathComponent })
        XCTAssertEqual(names, ["screenshot.png", "view-hierarchy.json"])
        XCTAssertTrue(SentryKSCrash.AttachmentsMonitor.Marker.isValid(at: markerURL(reportID: reportID)))
    }

    func testStitchedReport_whenMarkerMissing_shouldReturnOriginalReport() throws {
        // -- Arrange --
        let reportID: Int64 = 2
        let monitor = try makeMonitor(reportID: reportID)
        let original = ["crash": ["type": "mach"]] as NSDictionary

        // -- Act --
        let result = stitchedReport(monitor, report: original, reportID: reportID, scope: KSCrashSidecarScopeReport)

        // -- Assert --
        XCTAssertNil(result["attachments"])
        XCTAssertEqual(result["crash"] as? [String: String], ["type": "mach"])
    }

    func testStitchedReport_whenScopeIsRun_shouldReturnOriginalReport() throws {
        // -- Arrange --
        let reportID: Int64 = 3
        let monitor = try makeMonitor(reportID: reportID)
        monitor.setScreenshotWriter(testWritePNG)
        sentrykscrash_attachments_capture(reportID)
        let original = ["ok": true] as NSDictionary

        // -- Act --
        let result = stitchedReport(monitor, report: original, reportID: reportID, scope: KSCrashSidecarScopeRun)

        // -- Assert --
        XCTAssertNil(result["attachments"])
    }

    func testRemoveConsumedPayloadDirectories_whenPathIsOwned_shouldDeletePayloadDirectory() throws {
        // -- Arrange --
        let reportID: Int64 = 0x11
        let directory = payloadDirectory(reportID: reportID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("screenshot.png")
        try Data([0x01]).write(to: file)

        // -- Act --
        SentryKSCrash.AttachmentsMonitor.Layout.removeConsumedPayloadDirectories(
            for: [file]
        )

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testRemoveConsumedPayloadDirectories_whenMultipleFilesShareDirectory_shouldDeleteOnce() throws {
        // -- Arrange --
        let reportID: Int64 = 0x12
        let directory = payloadDirectory(reportID: reportID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let first = directory.appendingPathComponent("screenshot.png")
        let second = directory.appendingPathComponent("screenshot-2.png")
        try Data([0x01]).write(to: first)
        try Data([0x02]).write(to: second)

        // -- Act --
        SentryKSCrash.AttachmentsMonitor.Layout.removeConsumedPayloadDirectories(
            for: [first, second]
        )

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testRemoveConsumedPayloadDirectories_whenPathIsUnrelated_shouldNotDelete() throws {
        // -- Arrange --
        let directory = installDir.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("screenshot.png")
        try Data([0x01]).write(to: file)

        // -- Act --
        SentryKSCrash.AttachmentsMonitor.Layout.removeConsumedPayloadDirectories(
            for: [file]
        )

        // -- Assert --
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - Helpers

    private func makeMonitor(reportID: Int64) throws -> SentryKSCrash.AttachmentsMonitor {
        let sidecar = markerURL(reportID: reportID)
        try FileManager.default.createDirectory(
            at: sidecar.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let monitor = SentryKSCrash.AttachmentsMonitor()
        monitor.enabled = true
        var callbacks = KSCrash_ExceptionHandlerCallbacks()
        callbacks.getReportSidecarPath = { _, id, pathBuffer, length in
            guard let pathBuffer, let root = AttachmentsMonitorTestRoot.installDir else { return false }
            let path = SentryKSCrashAttachmentsMonitorTests.markerURL(installDir: root, reportID: id).path
            return path.withCString { source in
                let needed = strlen(source) + 1
                guard needed <= length else { return false }
                memcpy(pathBuffer, source, needed)
                return true
            }
        }
        monitor.callbacks = callbacks
        return monitor
    }

    private func stitchedReport(
        _ monitor: SentryKSCrash.AttachmentsMonitor,
        report: NSDictionary,
        reportID: Int64,
        scope: KSCrashSidecarScope
    ) -> NSDictionary {
        markerURL(reportID: reportID).path.withCString { pointer in
            let stitched = monitor.stitchedReport(
                reportDict: report,
                sidecarPath: pointer,
                scope: scope
            )
            return stitched.takeRetainedValue() as NSDictionary
        }
    }

    private func markerURL(reportID: Int64) -> URL {
        Self.markerURL(installDir: installDir, reportID: reportID)
    }

    private func payloadDirectory(reportID: Int64) -> URL {
        installDir
            .appendingPathComponent("SentryAttachments", isDirectory: true)
            .appendingPathComponent(String(format: "%016llx", UInt64(bitPattern: reportID)), isDirectory: true)
    }

    private static func markerURL(installDir: URL, reportID: Int64) -> URL {
        installDir
            .appendingPathComponent("Sidecars", isDirectory: true)
            .appendingPathComponent("SentryAttachments", isDirectory: true)
            .appendingPathComponent(String(format: "%016llx.ksscr", UInt64(bitPattern: reportID)))
    }
}
#endif
