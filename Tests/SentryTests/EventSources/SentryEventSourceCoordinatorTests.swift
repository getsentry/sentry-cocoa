#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryEventSourceCoordinatorTests: XCTestCase {

    func testIsAvailable_whenDownstreamIsAvailable_shouldReturnTrue() {
        // -- Arrange --
        let downstream = TestEventSourceSink()
        let sut = SentryEventSourceCoordinator(downstream: downstream)

        // -- Act & Assert --
        XCTAssertTrue(sut.isAvailable)
    }

    func testIsAvailable_whenDownstreamIsUnavailable_shouldReturnFalse() {
        // -- Arrange --
        let downstream = TestEventSourceSink()
        downstream.isAvailable = false
        let sut = SentryEventSourceCoordinator(downstream: downstream)

        // -- Act & Assert --
        XCTAssertFalse(sut.isAvailable)
    }

    func testSubmit_whenDownstreamAccepts_shouldForwardReportUnchanged() throws {
        // -- Arrange --
        let downstream = TestEventSourceSink()
        let sut = SentryEventSourceCoordinator(downstream: downstream)
        let event = Event(level: .error)
        let attachment = Attachment(data: Data("diagnostic".utf8), filename: "diagnostic.json")
        let report = SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [attachment]),
            runId: nil,
            event: event
        )

        // -- Act --
        let result = sut.submit(report)

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 1)
        let forwarded = try XCTUnwrap(downstream.submittedReports.first)
        XCTAssertEqual(forwarded.source, .metricKit)
        XCTAssertIdentical(forwarded.event, event)
        guard case .diagnostic(let attachments) = forwarded.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(attachments.count, 1)
        XCTAssertIdentical(attachments.first, attachment)
    }

    func testSubmit_whenDownstreamIsUnavailable_shouldReturnUnavailable() {
        // -- Arrange --
        let downstream = TestEventSourceSink()
        downstream.isAvailable = false
        let sut = SentryEventSourceCoordinator(downstream: downstream)
        let report = SentryEventSourceReport(
            source: .watchdogTermination,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: nil,
            event: Event(level: .fatal)
        )

        // -- Act --
        let result = sut.submit(report)

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(downstream.submittedReports.count, 0)
    }

    func testSubmit_whenSourceWithdrawsReport_shouldReturnWithdrawn() {
        // -- Arrange --
        let downstream = TestEventSourceSink()
        let sut = SentryEventSourceCoordinator(downstream: downstream)
        let report = SentryEventSourceReport(
            source: .crashHandler,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: true),
            runId: nil,
            event: Event(level: .fatal)
        )
        var beforeAcceptingInvocations = 0

        // -- Act --
        let result = sut.submit(report) {
            beforeAcceptingInvocations += 1
            return false
        }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(beforeAcceptingInvocations, 1)
        XCTAssertEqual(downstream.submittedReports.count, 0)
    }
}
