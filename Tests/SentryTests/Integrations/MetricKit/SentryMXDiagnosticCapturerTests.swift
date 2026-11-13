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
        guard case .diagnostic(let attachments) = report.kind else {
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
        guard case .diagnostic(let attachments) = report.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(attachments.count, 0)
    }

    func testCapture_whenDiagnosticIsEnabled_shouldSubmitReportWithoutRunId() throws {
        // -- Arrange --
        let eventSourceSink = TestEventSourceSink()
        let sut = givenSut(attachDiagnosticAsAttachment: false, eventSourceSink: eventSourceSink)

        // -- Act --
        sut.capture(try givenDiagnostic(report: .crash))

        // -- Assert --
        let report = try XCTUnwrap(eventSourceSink.submittedReports.first)
        XCTAssertNil(report.runId)
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

    private func givenSut(attachDiagnosticAsAttachment: Bool, eventSourceSink: SentryEventSourceSink) -> SentryMXDiagnosticCapturer {
        SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: attachDiagnosticAsAttachment,
            enabledDiagnostics: [.crash],
            // Every diagnostic counts as recorded by this process.
            processStartDate: .distantPast,
            eventSourceSink: eventSourceSink
        )
    }

    private func givenDiagnostic(report: SentryMetricKit.DiagnosticReport) throws -> SentryMXDiagnostic {
        let callStackTreeJSON = try contentsOfResource("MetricKitCallstacks/per-thread")
        return SentryMXDiagnostic(
            report: report,
            exceptionValue: { "MachException Type:nil Code:nil Signal:nil" },
            timestamp: Date(),
            metadata: SentryMXDiagnostic.Metadata(
                pid: nil,
                appVersion: "1.0.0",
                appBuild: "1",
                osVersion: nil,
                osBuild: nil,
                bundleIdentifier: nil,
                lowPowerModeEnabled: nil,
                isTestFlightApp: nil
            ),
            callStackTree: { try JSONDecoder().decode(SentryMXCallStackTree.self, from: callStackTreeJSON) },
            rawJSON: { Data("{}".utf8) },
            rawFilename: "MXDiagnosticPayload.json"
        )
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
