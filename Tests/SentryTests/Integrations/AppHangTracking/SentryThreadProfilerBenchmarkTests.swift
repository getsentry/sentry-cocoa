#if !SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryThreadProfilerBenchmarkTests: XCTestCase {
    func testStop_whenNotStarted_shouldReturnEmptyResults() async {
        // -- Arrange --
        let profiler = SentryThreadProfilerBenchmark()

        // -- Act --
        let result = await profiler.stop()

        // -- Assert --
        XCTAssertEqual(result.samples, 0)
        XCTAssertEqual(result.threads, 0)
        XCTAssertEqual(result.frames, 0)
        XCTAssertEqual(result.failures, 0)
        XCTAssertTrue(result.captureDurations.isEmpty)
    }

    func testStart_whenSampling_shouldCaptureThreadStacksAndTimings() async throws {
        // -- Arrange --
        let profiler = SentryThreadProfilerBenchmark()

        // -- Act --
        await profiler.start()
        try await Task.sleep(nanoseconds: 250_000_000)
        let result = await profiler.stop()

        // -- Assert --
        XCTAssertGreaterThan(result.samples, 0)
        XCTAssertGreaterThan(result.threads, 0)
        XCTAssertGreaterThan(result.frames, 0)
        XCTAssertEqual(result.failures, 0)
        XCTAssertEqual(result.captureDurations.count, result.samples)
        XCTAssertTrue(result.captureDurations.allSatisfy { $0 > 0 })
    }

    func testStart_whenClockDoesNotAdvance_shouldUseInjectedDateProvider() async throws {
        // -- Arrange --
        let dependencies = ClockDependencies()
        let profiler = SentryThreadProfilerBenchmark(dependencies: dependencies)

        // -- Act --
        await profiler.start()
        try await Task.sleep(nanoseconds: 250_000_000)
        let result = await profiler.stop()

        // -- Assert --
        XCTAssertGreaterThan(result.samples, 0)
        XCTAssertTrue(result.captureDurations.allSatisfy { $0 == 0 })
    }

    private struct ClockDependencies: ThreadInspectorProvider, CurrentDateProvider {
        let threadInspector = SentryThreadInspector(options: Options())
        let dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider()
    }

    func testStart_whenRestarted_shouldResetResults() async throws {
        // -- Arrange --
        let profiler = SentryThreadProfilerBenchmark()
        await profiler.start()
        try await Task.sleep(nanoseconds: 250_000_000)
        let first = await profiler.stop()

        // -- Act --
        await profiler.start()
        let second = await profiler.stop()

        // -- Assert --
        XCTAssertGreaterThan(first.samples, 0)
        XCTAssertLessThan(second.samples, first.samples)
        XCTAssertEqual(second.captureDurations.count, second.samples)
    }
}
#endif
