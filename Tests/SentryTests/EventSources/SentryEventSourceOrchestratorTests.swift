@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryEventSourceOrchestratorTests: XCTestCase {

    func testWatchdogTerminationAwaitingMetricKit_shouldHoldWatchdogTerminationsForMetricKit() {
        // -- Act --
        let sut = SentryEventSourceOrchestrator.watchdogTerminationAwaitingMetricKit

        // -- Assert --
        XCTAssertEqual(sut.heldSource, .watchdogTermination)
        XCTAssertEqual(sut.awaitedSource, .metricKit)
        XCTAssertEqual(sut.holdDuration, 30)
    }

    func testWatchdogTerminationAwaitingMetricKit_whenMerging_shouldEnrichTheHeldEvent() throws {
        // -- Arrange --
        let sut = SentryEventSourceOrchestrator.watchdogTerminationAwaitingMetricKit
        let heldEvent = Event(level: .fatal)
        let exception = Exception(value: SentryWatchdogTerminationConstants.ExceptionValue, type: SentryWatchdogTerminationConstants.ExceptionType)
        exception.mechanism = Mechanism(type: SentryWatchdogTerminationConstants.MechanismType)
        heldEvent.exceptions = [exception]
        let held = SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: heldEvent)
        let diagnosticEvent = Event(level: .error)
        diagnosticEvent.exceptions = [Exception(value: "value", type: "MXCrashDiagnostic")]
        let diagnostic = SentryEventSourceReport(source: .metricKit, kind: .diagnostic(attachments: [], runEnd: .crash(terminationReason: "Namespace SPRINGBOARD, Code 0x8badf00d")), runId: held.runId, event: diagnosticEvent)

        // -- Act --
        let merged = sut.merge(held, diagnostic, .crash(terminationReason: "Namespace SPRINGBOARD, Code 0x8badf00d"))

        // -- Assert --
        let mergedException = try XCTUnwrap(merged.exceptions?.first)
        XCTAssertEqual(mergedException.type, SentryWatchdogTerminationConstants.ExceptionType)
        XCTAssertEqual(mergedException.mechanism?.data?[SentryHeldFatalReportEnrichment.terminationReasonKey] as? String, "Namespace SPRINGBOARD, Code 0x8badf00d")
    }

    #if os(iOS) || os(macOS) || os(visionOS)
    func testEnabled_whenCrashDiagnosticsAreEnabled_shouldHoldWatchdogTerminationsForMetricKit() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]

        // -- Act --
        let orchestrators = SentryEventSourceOrchestrator.enabled(for: options)

        // -- Assert --
        XCTAssertEqual(orchestrators.count, 1)
        XCTAssertEqual(try XCTUnwrap(orchestrators.first).heldSource, .watchdogTermination)
        XCTAssertEqual(try XCTUnwrap(orchestrators.first).awaitedSource, .metricKit)
    }

    func testEnabled_whenMemoryExceptionDiagnosticsAreEnabled_shouldHoldWatchdogTerminationsForMetricKit() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.memoryException]

        // -- Act --
        let orchestrators = SentryEventSourceOrchestrator.enabled(for: options)

        // -- Assert --
        XCTAssertEqual(orchestrators.count, 1)
        XCTAssertEqual(try XCTUnwrap(orchestrators.first).heldSource, .watchdogTermination)
    }

    func testEnabled_whenOnlyOtherDiagnosticsAreEnabled_shouldReturnNoOrchestrator() {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]

        // -- Act & Assert --
        XCTAssertEqual(SentryEventSourceOrchestrator.enabled(for: options).count, 0)
    }
    #endif // os(iOS) || os(macOS) || os(visionOS)

    func testEnabled_whenNoDiagnosticsAreEnabled_shouldReturnNoOrchestrator() {
        // -- Arrange --
        let options = Options()
        #if os(iOS) || os(macOS) || os(visionOS)
        options.experimental.metrickit.enabledDiagnosticReports = []
        #endif // os(iOS) || os(macOS) || os(visionOS)

        // -- Act & Assert --
        XCTAssertEqual(SentryEventSourceOrchestrator.enabled(for: options).count, 0)
    }
}
