@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

/// Covers how `SentryMXRunStore` records the runs MetricKit diagnostics are matched to.
final class SentryMXRunStoreTests: XCTestCase {

    private var directory: String!
    private var dateProvider: TestCurrentDateProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = (NSTemporaryDirectory() as NSString).appendingPathComponent("SentryMXRunStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 10_000))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(atPath: directory)
        try super.tearDownWithError()
    }

    // MARK: - Recording

    func testRecordPreviousRun_whenFirstLaunch_shouldNotRecordFatalRun() {
        // -- Arrange --
        let sut = givenStore(pid: 100, start: 1_000)

        // -- Act --
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
        XCTAssertNil(sut.previousRun)
    }

    func testRecordPreviousRun_whenPreviousRunCrashed_shouldRecordItAsReportedByCrashHandler() {
        // -- Arrange --
        let previous = givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Act --
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [
            SentryMXFatalRun(
                runId: previous.currentRun.runId,
                pid: 100,
                start: Date(timeIntervalSince1970: 1_000),
                // The previous run ended before the running process started.
                end: Date(timeIntervalSince1970: 2_000),
                report: .crashHandler
            )
        ])
    }

    func testRecordPreviousRun_whenPreviousRunWasWatchdogTerminated_shouldRecordItAsWatchdogTermination() {
        // -- Arrange --
        givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Act --
        sut.recordPreviousRun(crashed: false, watchdogTerminated: true)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns.map(\.report), [.watchdogTermination])
    }

    func testRecordPreviousRun_whenPreviousRunDidNotEndFatally_shouldNotRecordFatalRun() {
        // -- Arrange --
        let previous = givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Act --
        sut.recordPreviousRun(crashed: false, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
        XCTAssertEqual(sut.previousRun, previous.currentRun)
    }

    func testRecordPreviousRun_whenCalledAgainInSameProcess_shouldNotRecordRunningProcess() {
        // -- Arrange --
        givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)
        sut.recordPreviousRun(crashed: false, watchdogTerminated: false)

        // -- Act --
        // Starting the SDK again in the same process must not record the running process as the
        // previous run.
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
    }

    func testRecordPreviousRun_whenSeveralRunsEndedFatally_shouldKeepAll() {
        // -- Arrange --
        givenLaunchedStore(pid: 100, start: 1_000)
        let second = givenStore(pid: 200, start: 2_000)
        second.recordPreviousRun(crashed: true, watchdogTerminated: false)
        let sut = givenStore(pid: 300, start: 3_000)

        // -- Act --
        sut.recordPreviousRun(crashed: false, watchdogTerminated: true)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns.map(\.pid), [100, 200])
        XCTAssertEqual(sut.fatalRuns.map(\.report), [.crashHandler, .watchdogTermination])
    }

    // MARK: - Previous run

    func testPreviousRun_whenRunningProcessDidNotRecordLaunch_shouldReturnLastRun() {
        // -- Arrange --
        let previous = givenLaunchedStore(pid: 100, start: 1_000)

        // -- Act --
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Assert --
        XCTAssertEqual(sut.previousRun, previous.currentRun)
    }

    func testPreviousRun_whenRunningProcessRecordedLaunch_shouldStillReturnRunBefore() {
        // -- Arrange --
        let previous = givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Act --
        sut.recordPreviousRun(crashed: false, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.previousRun, previous.currentRun)
    }

    // MARK: - Reading

    func testFatalRuns_whenRunIsOlderThanMaxAge_shouldNotReturnIt() {
        // -- Arrange --
        givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)

        // -- Act --
        dateProvider.setDate(date: Date(timeIntervalSince1970: 2_001 + SentryMXFatalRunHistory.maxAge))

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
    }

    func testRemove_shouldNotMatchRunAgain() throws {
        // -- Arrange --
        givenLaunchedStore(pid: 100, start: 1_000)
        let sut = givenStore(pid: 200, start: 2_000)
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)
        let run = try XCTUnwrap(sut.fatalRuns.first)

        // -- Act --
        sut.remove(run)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
        XCTAssertEqual(givenStore(pid: 300, start: 3_000).fatalRuns, [])
    }

    func testRecordPreviousRun_whenFileIsCorrupt_shouldStartOver() throws {
        // -- Arrange --
        try Data("not json".utf8).write(to: URL(fileURLWithPath: (directory as NSString).appendingPathComponent("metrickit-runs.json")))
        let sut = givenStore(pid: 200, start: 2_000)

        // -- Act --
        sut.recordPreviousRun(crashed: true, watchdogTerminated: false)

        // -- Assert --
        XCTAssertEqual(sut.fatalRuns, [])
        XCTAssertNil(sut.previousRun)
        XCTAssertNotNil(givenStore(pid: 300, start: 3_000).previousRun)
    }

    // MARK: - Helpers

    private func givenStore(pid: pid_t, start: TimeInterval) -> SentryMXRunStore {
        SentryMXRunStore(
            path: (directory as NSString).appendingPathComponent("metrickit-runs.json"),
            currentRun: SentryMXRunStore.Run(runId: UUID(), pid: pid, start: Date(timeIntervalSince1970: start)),
            dateProvider: dateProvider
        )
    }

    /// A run that recorded its launch and then ended.
    @discardableResult
    private func givenLaunchedStore(pid: pid_t, start: TimeInterval) -> SentryMXRunStore {
        let store = givenStore(pid: pid, start: start)
        store.recordPreviousRun(crashed: false, watchdogTerminated: false)
        return store
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
