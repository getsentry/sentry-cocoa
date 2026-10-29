#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import StateReporting
#endif

#if os(iOS) || os(macOS) || os(visionOS)

/// Covers how MetricKit diagnostics are matched to recorded fatal runs, see decision 41 in
/// `develop-docs/DECISIONS.md`.
final class SentryMXRunMatcherTests: XCTestCase {

    // MARK: - Run ID

    func testMatch_whenRunIdIsRecorded_shouldMatchRun() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)
        let other = givenRun(pid: 200, start: 100, end: 200)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(runIds: [run.runId]), in: [run, other])

        // -- Assert --
        XCTAssertEqual(match, .run(run))
    }

    func testMatch_whenRunIdIsNotRecorded_shouldNotFallBackToPid() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)

        // -- Act --
        // The process ID and time range match, but the run ID says the diagnostic belongs to a
        // run that didn't end fatally.
        let match = SentryMXRunMatcher.match(givenDiagnostic(runIds: [UUID()], pid: 100, from: 10, to: 20), in: [run])

        // -- Assert --
        XCTAssertEqual(match, .unmatched)
    }

    func testMatch_whenDiagnosticCarriesSeveralRunIds_shouldBeAmbiguous() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)
        let other = givenRun(pid: 200, start: 100, end: 200)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(runIds: [run.runId, other.runId]), in: [run, other])

        // -- Assert --
        XCTAssertEqual(match, .ambiguous)
    }

    func testMatch_whenDiagnosticCarriesSameRunIdTwice_shouldMatchRun() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(runIds: [run.runId, run.runId]), in: [run])

        // -- Assert --
        XCTAssertEqual(match, .run(run))
    }

    // MARK: - Process ID and lifetime

    func testMatch_whenPidMatchesAndTimeRangeOverlapsLifetime_shouldMatchRun() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)
        let other = givenRun(pid: 200, start: 100, end: 200)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 50, to: 150), in: [run, other])

        // -- Assert --
        XCTAssertEqual(match, .run(run))
    }

    func testMatch_whenPidMatchesButTimeRangeIsOutsideLifetime_shouldNotMatch() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 150, to: 200), in: [run])

        // -- Assert --
        XCTAssertEqual(match, .unmatched)
    }

    func testMatch_whenPidIsReused_shouldMatchRunWhoseLifetimeOverlaps() {
        // -- Arrange --
        // Both runs got process ID 100. A start time alone would match both, because both started
        // before the diagnostic's time range.
        let earlier = givenRun(pid: 100, start: 0, end: 100)
        let later = givenRun(pid: 100, start: 1_000, end: 1_100)

        // -- Act --
        let match = SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 1_050, to: 1_060), in: [earlier, later])

        // -- Assert --
        XCTAssertEqual(match, .run(later))
    }

    func testMatch_whenTimeRangeOverlapsRunsWithReusedPid_shouldBeAmbiguous() {
        // -- Arrange --
        let earlier = givenRun(pid: 100, start: 0, end: 100)
        let later = givenRun(pid: 100, start: 1_000, end: 1_100)

        // -- Act --
        // A payload covering a whole day can overlap both runs.
        let match = SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 0, to: 86_400), in: [earlier, later])

        // -- Assert --
        XCTAssertEqual(match, .ambiguous)
    }

    func testMatch_whenNeitherRunIdNorPidIsReported_shouldNotMatch() {
        // -- Arrange --
        let run = givenRun(pid: 100, start: 0, end: 100)

        // -- Act --
        // Before iOS 17 and macOS 14, a time range alone can't tell apart several runs.
        let match = SentryMXRunMatcher.match(givenDiagnostic(from: 10, to: 20), in: [run])

        // -- Assert --
        XCTAssertEqual(match, .unmatched)
    }

    func testMatch_whenNextRunStartedBeforeRun_shouldUseEmptyLifetime() {
        // -- Arrange --
        // The clock went backwards between the runs.
        let run = givenRun(pid: 100, start: 100, end: 50)

        // -- Act & Assert --
        XCTAssertEqual(SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 100, to: 110), in: [run]), .run(run))
        XCTAssertEqual(SentryMXRunMatcher.match(givenDiagnostic(pid: 100, from: 50, to: 90), in: [run]), .unmatched)
    }

    // MARK: - History

    func testAdd_whenRunIsOlderThanMaxAge_shouldRemoveIt() {
        // -- Arrange --
        var sut = SentryMXFatalRunHistory()
        let old = givenRun(pid: 100, start: 0, end: 100)
        let recent = givenRun(pid: 200, start: 100, end: SentryMXFatalRunHistory.maxAge)
        sut.add(old, now: Date(timeIntervalSince1970: 100))

        // -- Act --
        sut.add(recent, now: Date(timeIntervalSince1970: 101 + SentryMXFatalRunHistory.maxAge))

        // -- Assert --
        XCTAssertEqual(sut.runs, [recent])
    }

    func testAdd_whenMoreRunsThanMaxCount_shouldKeepLatestRuns() {
        // -- Arrange --
        var sut = SentryMXFatalRunHistory()
        let runs = (0..<SentryMXFatalRunHistory.maxCount + 2).map {
            givenRun(pid: pid_t($0), start: TimeInterval($0), end: TimeInterval($0 + 1))
        }

        // -- Act --
        runs.forEach { sut.add($0, now: Date(timeIntervalSince1970: 100)) }

        // -- Assert --
        XCTAssertEqual(sut.runs, Array(runs.suffix(SentryMXFatalRunHistory.maxCount)))
    }

    func testRemove_shouldOnlyRemoveRun() {
        // -- Arrange --
        var sut = SentryMXFatalRunHistory()
        let run = givenRun(pid: 100, start: 0, end: 100)
        let other = givenRun(pid: 200, start: 100, end: 200)
        sut.add(run, now: Date(timeIntervalSince1970: 200))
        sut.add(other, now: Date(timeIntervalSince1970: 200))

        // -- Act --
        sut.remove(run)

        // -- Assert --
        XCTAssertEqual(sut.runs, [other])
    }

    func testCodable_shouldRoundTripHistory() throws {
        // -- Arrange --
        var sut = SentryMXFatalRunHistory()
        sut.add(givenRun(pid: 100, start: 0, end: 100, report: .crashHandler), now: Date(timeIntervalSince1970: 200))
        sut.add(givenRun(pid: 200, start: 100, end: 200), now: Date(timeIntervalSince1970: 200))

        // -- Act --
        let decoded = try JSONDecoder().decode(SentryMXFatalRunHistory.self, from: JSONEncoder().encode(sut))

        // -- Assert --
        XCTAssertEqual(decoded, sut)
    }

    // MARK: - Helpers

    private func givenRun(pid: pid_t, start: TimeInterval, end: TimeInterval, report: SentryMXFatalRun.Report = .watchdogTermination) -> SentryMXFatalRun {
        SentryMXFatalRun(
            runId: UUID(),
            pid: pid,
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            report: report
        )
    }

    private func givenDiagnostic(runIds: [UUID] = [], pid: pid_t? = nil, from: TimeInterval = 0, to: TimeInterval = 10) -> SentryMXDiagnosticRun {
        SentryMXDiagnosticRun(
            runIds: runIds,
            pid: pid,
            timeRange: DateInterval(start: Date(timeIntervalSince1970: from), end: Date(timeIntervalSince1970: to))
        )
    }
}

#if compiler(>=6.4) && (os(iOS) || os(macOS))

final class SentryMXRunStateTests: XCTestCase {

    func testRunId_whenStateIsSentrys_shouldReturnRunId() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("State reporting requires iOS or macOS 27")
        }
        // -- Arrange --
        let runId = UUID()
        let metadata = SentryMXRunState.Metadata(runId: runId).metadataDictionary

        // -- Act --
        let result = SentryMXRunState.runId(domain: "io.sentry.run", stableMetadata: metadata)

        // -- Assert --
        XCTAssertEqual(result, runId)
    }

    func testRunId_whenStateIsFromAppDomain_shouldIgnoreIt() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("State reporting requires iOS or macOS 27")
        }
        // -- Arrange --
        let metadata = SentryMXRunState.Metadata(runId: UUID()).metadataDictionary

        // -- Act & Assert --
        XCTAssertNil(SentryMXRunState.runId(domain: "com.example.app", stableMetadata: metadata))
    }

    func testRunId_whenValueIsNotUUID_shouldIgnoreIt() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("State reporting requires iOS or macOS 27")
        }
        // -- Act & Assert --
        XCTAssertNil(SentryMXRunState.runId(domain: "io.sentry.run", stableMetadata: ["run_id": ReportableMetadataValue("not-a-uuid")]))
        XCTAssertNil(SentryMXRunState.runId(domain: "io.sentry.run", stableMetadata: ["run_id": ReportableMetadataValue(1)]))
    }
}
#endif // compiler(>=6.4) && (os(iOS) || os(macOS))

#endif // os(iOS) || os(macOS) || os(visionOS)
