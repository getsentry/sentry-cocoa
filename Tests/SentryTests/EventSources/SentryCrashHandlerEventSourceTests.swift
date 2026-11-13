#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryCrashHandlerEventSourceTests: XCTestCase {

    func testIsAvailable_shouldReturnAvailabilityOfSink() {
        // -- Arrange --
        let sink = TestEventSourceSink()
        let sut = SentryCrashHandlerEventSource(sink: sink)

        // -- Act & Assert --
        XCTAssertTrue(sut.isAvailable)
        sink.isAvailable = false
        XCTAssertFalse(sut.isAvailable)
    }

    func testSubmit_whenAccepted_shouldSubmitFatalReportOfCrashHandler() throws {
        // -- Arrange --
        let sink = TestEventSourceSink()
        let sut = SentryCrashHandlerEventSource(sink: sink)
        let event = Event(level: .fatal)
        let crashReport: [AnyHashable: Any] = [
            "user": [SentryCurrentRun.userInfoKey: "run-id"],
            "attachments": ["/tmp/screenshot.png", 7, "/tmp/view-hierarchy.json"]
        ]

        // -- Act --
        let result = sut.submit(event, crashReport: crashReport, isRetainedOnFailure: true, beforeAccepting: { true })

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        let report = try XCTUnwrap(sink.submittedReports.first)
        XCTAssertEqual(report.source, .crashHandler)
        XCTAssertIdentical(report.event, event)
        XCTAssertEqual(report.runId, SentryCurrentRun.ID(rawValue: "run-id"))
        guard case let .fatal(attachmentPaths, isRetainedOnFailure) = report.kind else {
            return XCTFail("Expected a fatal report")
        }
        XCTAssertEqual(attachmentPaths, ["/tmp/screenshot.png", "/tmp/view-hierarchy.json"])
        XCTAssertTrue(isRetainedOnFailure)
    }

    func testSubmit_whenReportHasNoRunIdAndNoAttachments_shouldSubmitReportWithoutThem() throws {
        // -- Arrange --
        let sink = TestEventSourceSink()
        let sut = SentryCrashHandlerEventSource(sink: sink)

        // -- Act --
        let result = sut.submit(
            Event(level: .fatal),
            crashReport: ["attachments": "not-an-array"],
            isRetainedOnFailure: false,
            beforeAccepting: { true }
        )

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        let report = try XCTUnwrap(sink.submittedReports.first)
        XCTAssertNil(report.runId)
        guard case let .fatal(attachmentPaths, isRetainedOnFailure) = report.kind else {
            return XCTFail("Expected a fatal report")
        }
        XCTAssertEqual(attachmentPaths, [])
        XCTAssertFalse(isRetainedOnFailure)
    }

    func testSubmit_whenSinkIsUnavailable_shouldReturnUnavailable() {
        // -- Arrange --
        let sink = TestEventSourceSink()
        sink.isAvailable = false
        let sut = SentryCrashHandlerEventSource(sink: sink)

        // -- Act --
        let result = sut.submit(Event(level: .fatal), crashReport: [:], isRetainedOnFailure: true, beforeAccepting: { true })

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(sink.submittedReports.count, 0)
    }

    func testSubmit_whenBeforeAcceptingReturnsFalse_shouldReturnWithdrawn() {
        // -- Arrange --
        let sink = TestEventSourceSink()
        let sut = SentryCrashHandlerEventSource(sink: sink)

        // -- Act --
        let result = sut.submit(Event(level: .fatal), crashReport: [:], isRetainedOnFailure: true, beforeAccepting: { false })

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(sink.submittedReports.count, 0)
    }
}
