import KSCrashRecording
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class KSCrashReportSinkTests: XCTestCase {

    func test_filterReports_emptyArray_callsCompletionWithNoError() {
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let expectation = expectation(description: "completion")
        sink.filterReports([]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func test_filterReports_nonDictionaryReport_isSkipped() {
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let stringReport = CrashReportString.report(withValue: "{}")
        let expectation = expectation(description: "completion")
        sink.filterReports([stringReport]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func test_filterReports_emptyDictionaryReport_noClientSet_doesNotCrash() {
        // With no Sentry client configured, the sink should handle an empty report
        // gracefully (the converter will return nil) and still call completion.
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let report = CrashReportDictionary.report(withValue: [:])
        let expectation = expectation(description: "completion")
        sink.filterReports([report]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func test_filterReports_loadsAndAttachesSavedFiles() throws {
        // -- Arrange --
        let reportIDHex = "000000000000abcd"
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("SentryAttachmentTest-\(UUID().uuidString)")
        let attachDir = tempBase.appendingPathComponent(reportIDHex)
        try FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)
        // swiftlint:disable:next no_try_optional_in_tests
        defer { try? FileManager.default.removeItem(at: tempBase) }

        try Data([0x89, 0x50, 0x4E, 0x47])
            .write(to: attachDir.appendingPathComponent("screenshot.png"))
        try Data("{\"windows\":[]}".utf8)
            .write(to: attachDir.appendingPathComponent("view-hierarchy.json"))

        SentryCrashAttachmentsStorage.basePath = tempBase.path
        defer { SentryCrashAttachmentsStorage.basePath = nil }

        // Minimal crash report dictionary carrying the report ID.
        let report = CrashReportDictionary.report(withValue: [
            "report": ["id": reportIDHex]
        ])

        // Wire up the SDK so captureFatalEvent doesn't bail.
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "KSCrashReportSinkTests")
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        defer { SentrySDKInternal.setCurrentHub(nil) }

        let sink = KSCrashReportSink(inAppLogic: SentryInAppLogic(inAppIncludes: []))
        let done = expectation(description: "completion")

        // -- Act --
        sink.filterReports([report]) { _, _ in done.fulfill() }
        wait(for: [done], timeout: 2.0)

        // -- Assert --
        let capturedScope = try XCTUnwrap(hub.sentFatalEventsWithScope.invocations.first?.scope)
        let attachmentFilenames = capturedScope.attachments.compactMap { $0.filename }
        XCTAssertTrue(attachmentFilenames.contains("screenshot.png"))
        XCTAssertTrue(attachmentFilenames.contains("view-hierarchy.json"))

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: attachDir.path),
            "Attachments directory should be deleted after capture"
        )
    }
}
