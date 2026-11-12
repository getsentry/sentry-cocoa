#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

final class SentryMXDiagnosticCapturerTests: XCTestCase {

    func testCapture_whenDiagnosticIsEnabled_shouldSubmitDiagnosticReportToEventSourceSink() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: true, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        XCTAssertEqual(eventSourceSink.submittedReports.count, 1)
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        XCTAssertEqual(report.source, .metricKit)
        XCTAssertEqual(report.event.exceptions?.first?.type, "MXCrashDiagnostic")
        guard case .diagnostic(let attachments, _) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(attachments.map(\.filename), ["MXDiagnosticPayload.json"])
    }

    func testCapture_whenRawPayloadIsNotAttached_shouldSubmitReportWithoutAttachments() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        guard case .diagnostic(let attachments, _) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(attachments.count, 0)
    }

    func testCapture_whenDiagnosticIsACrash_shouldSubmitReportThatEndsTheRunWithACrash() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        guard case .diagnostic(_, let runEnd) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(runEnd, .crash(terminationReason: nil))
    }

    func testCapture_whenDiagnosticIsAMemoryException_shouldSubmitReportThatEndsTheRunWithAMemoryTermination() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink, enabledDiagnostics: [.memoryException])

        // -- Act --
        sut.capture(try givenDiagnostic(report: .memoryException))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        guard case .diagnostic(_, let runEnd) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(runEnd, .memoryTermination)
    }

    func testCapture_whenDiagnosticIsAHang_shouldSubmitReportThatDoesNotEndTheRun() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink, enabledDiagnostics: [.hang])

        // -- Act --
        sut.capture(try givenDiagnostic(report: .hang))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        guard case .diagnostic(_, let runEnd) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertNil(runEnd)
    }

    func testCapture_whenThereIsNoRunIdDecoder_shouldSubmitReportWithoutRunId() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        XCTAssertNil(report.runId)
    }

    func testCapture_whenRunIdDecoderFindsTheRun_shouldSubmitReportWithItsRunId() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let runIdDecoder = TestRunIdDecoder(runId: SentryCurrentRun.ID(rawValue: "run-1"))
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink, runIdDecoder: runIdDecoder)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        XCTAssertEqual(report.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertEqual(runIdDecoder.decodedCallStackTrees.count, 1)
    }

    func testCapture_whenCallStackTreeCantBeDecoded_shouldSubmitReportWithoutRunId() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let runIdDecoder = TestRunIdDecoder(runId: SentryCurrentRun.ID(rawValue: "run-1"))
        let sut = givenSut(attachDiagnosticAsAttachment: true, eventSourceSink: eventSourceSink, runIdDecoder: runIdDecoder)
        let diagnostic = SentryMXDiagnostic(
            report: .crash,
            exceptionValue: { "" },
            timestamp: Date(),
            metadata: SentryMXDiagnostic.Metadata(pid: nil, appVersion: "1.0.0", appBuild: "1", osVersion: nil, osBuild: nil),
            callStackTree: { throw NSError(domain: "test", code: 1) },
            rawJSON: { Data("{}".utf8) },
            rawFilename: "MXDiagnosticPayload.json"
        )

        // -- Act --
        sut.capture(diagnostic)

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        XCTAssertNil(report.runId)
        XCTAssertEqual(runIdDecoder.decodedCallStackTrees.count, 0)
    }

    func testCapture_whenDiagnosticIsDisabled_shouldNotSubmitReport() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .hang))

        // -- Assert --
        XCTAssertEqual(eventSourceSink.submittedReports.count, 0)
    }

    // MARK: - Helpers

    private func givenSut(
        attachDiagnosticAsAttachment: Bool,
        eventSourceSink: SentryEventSourceSink,
        runIdDecoder: SentryMXRunIdDecoding? = nil,
        enabledDiagnostics: Set<SentryMetricKit.DiagnosticReport> = [.crash]
    ) -> SentryMXDiagnosticCapturer {
        SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: attachDiagnosticAsAttachment,
            enabledDiagnostics: enabledDiagnostics,
            // Every diagnostic counts as recorded by this process.
            processStartDate: .distantPast,
            eventSourceSink: eventSourceSink,
            runIdDecoder: runIdDecoder
        )
    }

    private final class TestRunIdDecoder: SentryMXRunIdDecoding {
        let runId: SentryCurrentRun.ID?
        private(set) var decodedCallStackTrees: [SentryMXCallStackTree] = []

        init(runId: SentryCurrentRun.ID?) {
            self.runId = runId
        }

        func runId(of callStackTree: SentryMXCallStackTree) -> SentryCurrentRun.ID? {
            decodedCallStackTrees.append(callStackTree)
            return runId
        }
    }

    private func givenDiagnostic(report: SentryMetricKit.DiagnosticReport) throws -> SentryMXDiagnostic {
        let callStackTreeJSON = try contentsOfResource("MetricKitCallstacks/per-thread")
        return SentryMXDiagnostic(
            report: report,
            exceptionValue: { "MachException Type:nil Code:nil Signal:nil" },
            timestamp: Date(),
            metadata: SentryMXDiagnostic.Metadata(pid: nil, appVersion: "1.0.0", appBuild: "1", osVersion: nil, osBuild: nil),
            callStackTree: { try JSONDecoder().decode(SentryMXCallStackTree.self, from: callStackTreeJSON) },
            rawJSON: { Data("{}".utf8) },
            rawFilename: "MXDiagnosticPayload.json"
        )
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
