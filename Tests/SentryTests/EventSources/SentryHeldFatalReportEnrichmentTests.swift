#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryHeldFatalReportEnrichmentTests: XCTestCase {
    func testEnrich_whenRunEndIsWatchdogTermination_shouldKeepExceptionAndAddStackTraceAndReason() throws {
        // -- Arrange --
        let held = givenHeldReport()
        let diagnostic = givenDiagnostic()

        // -- Act --
        let event = SentryHeldFatalReportEnrichment.enrich(held, with: diagnostic, runEnd: .crash(terminationReason: "Namespace SPRINGBOARD, Code 0x8badf00d"))

        // -- Assert --
        XCTAssertIdentical(event, held.event)
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(event.exceptions?.count, 1)
        XCTAssertEqual(exception.type, "WatchdogTermination")
        XCTAssertEqual(exception.value, "watchdog value")
        XCTAssertEqual(exception.mechanism?.type, "watchdog_termination")
        XCTAssertEqual(exception.mechanism?.handled, false)
        XCTAssertEqual(exception.mechanism?.data?["termination_reason"] as? String, "Namespace SPRINGBOARD, Code 0x8badf00d")
        XCTAssertEqual(exception.threadId, 7)
        XCTAssertEqual(exception.stacktrace?.frames.count, 2)
        XCTAssertEqual(event.threads?.count, 1)
        XCTAssertEqual(event.debugMeta?.count, 1)
        XCTAssertEqual(event.tags, ["previous": "run"])
    }

    func testEnrich_whenRunEndIsMemoryTermination_shouldUseDiagnosticValueAsReason() throws {
        // -- Arrange --
        let held = givenHeldReport()
        let diagnostic = givenDiagnostic(value: "The app or extension exceeded its memory limit")

        // -- Act --
        let event = SentryHeldFatalReportEnrichment.enrich(held, with: diagnostic, runEnd: .memoryTermination)

        // -- Assert --
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(exception.type, "WatchdogTermination")
        XCTAssertEqual(exception.mechanism?.data?["termination_reason"] as? String, "The app or extension exceeded its memory limit")
        XCTAssertEqual(exception.stacktrace?.frames.count, 2)
    }

    func testEnrich_whenRunEndIsAnotherCrash_shouldReplaceExceptionWithDiagnostics() throws {
        // -- Arrange --
        let held = givenHeldReport()
        let diagnostic = givenDiagnostic()

        // -- Act --
        let event = SentryHeldFatalReportEnrichment.enrich(held, with: diagnostic, runEnd: .crash(terminationReason: "Namespace SIGNAL, Code 0xb"))

        // -- Assert --
        let exception = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(event.exceptions?.count, 1)
        XCTAssertEqual(exception.type, "MXCrashDiagnostic")
        XCTAssertEqual(exception.value, "diagnostic value")
        XCTAssertEqual(exception.stacktrace?.frames.count, 2)
        XCTAssertEqual(event.threads?.count, 1)
        XCTAssertEqual(event.debugMeta?.count, 1)
        XCTAssertEqual(event.level, .fatal)
        XCTAssertEqual(event.tags, ["previous": "run"])
    }

    func testEnrich_whenHeldEventHasNoException_shouldOnlyAddThreadsAndDebugMeta() {
        // -- Arrange --
        let held = SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal))
        let diagnostic = givenDiagnostic()

        // -- Act --
        let event = SentryHeldFatalReportEnrichment.enrich(held, with: diagnostic, runEnd: .memoryTermination)

        // -- Assert --
        XCTAssertNil(event.exceptions)
        XCTAssertEqual(event.threads?.count, 1)
        XCTAssertEqual(event.debugMeta?.count, 1)
    }

    // MARK: - Helpers

    private func givenHeldReport() -> SentryHeldFatalReport {
        let event = Event(level: .fatal)
        event.tags = ["previous": "run"]
        let exception = Exception(value: "watchdog value", type: "WatchdogTermination")
        let mechanism = Mechanism(type: "watchdog_termination")
        mechanism.handled = false
        exception.mechanism = mechanism
        event.exceptions = [exception]
        return SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: event)
    }

    private func givenDiagnostic(value: String = "diagnostic value") -> SentryEventSourceReport {
        let event = Event(level: .error)
        let thread = SentryThread(threadId: 7)
        thread.crashed = true
        thread.stacktrace = SentryStacktrace(frames: [Frame(), Frame()], registers: [:])
        let exception = Exception(value: value, type: "MXCrashDiagnostic")
        exception.mechanism = Mechanism(type: "MXCrashDiagnostic")
        exception.stacktrace = thread.stacktrace
        exception.threadId = thread.threadId
        event.exceptions = [exception]
        event.threads = [thread]
        event.debugMeta = [DebugMeta()]
        return SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [], runEnd: nil),
            runId: SentryCurrentRun.ID(rawValue: "run-1"),
            event: event
        )
    }
}
