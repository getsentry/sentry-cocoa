#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import SentryTestUtilsObjCpp
import XCTest

#if os(iOS) || os(macOS)
final class SentryTraceProfilerTests: XCTestCase {
    private struct Fixture {
        let dateProvider = TestCurrentDateProvider()
        let queue = TestSentryDispatchQueueWrapper()
        let notifications = TestNSNotificationCenterWrapper()
        let timerFactory: TestSentryNSTimerFactory
        let client: TestClient
        let hub: SentryHubInternal

        init() throws {
            let container = SentryDependencyContainer.sharedInstance()
            container.dateProvider = dateProvider
            container.dispatchQueueWrapper = queue
            container.dispatchFactory = TestDispatchFactory()
            container.notificationCenterWrapper = notifications
            timerFactory = TestSentryNSTimerFactory(currentDateProvider: dateProvider)
            container.timerFactory = timerFactory
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryTraceProfilerTests.self)
            options.tracesSampleRate = 1
            client = try XCTUnwrap(TestClient(options: options))
            hub = SentryHubInternal(client: client, andScope: Scope())
            SentrySDKInternal.setCurrentHub(hub)
        }
    }

    private var fixture: Fixture!
    private var traceIDs: [SentryId] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        if sentry_threadSanitizerIsPresent() {
            throw XCTSkip("Profiling is disabled when Thread Sanitizer is attached.")
        }
        fixture = try Fixture()
    }

    override func tearDown() {
        traceIDs.forEach { SentrySDK.internal.profiling.discard(for: $0) }
        fixture?.timerFactory.overrides?.timer.invalidate()
        // These tests replace process-wide SDK and profiling dependencies.
        // swiftlint:disable:next avoid_clear_test_state
        clearTestState()
        super.tearDown()
    }

    func testTimeout_whenPreviousTraceIsDiscarded_shouldGiveReplacementItsOwnDeadline() throws {
        // -- Arrange --
        let firstID = try startTrace()
        fixture.dateProvider.advance(by: 10)
        SentrySDK.internal.profiling.discard(for: firstID)
        _ = try startTrace()
        let nextProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())

        // -- Act --
        fixture.dateProvider.advance(by: 20)
        try fixture.timerFactory.check()

        // -- Assert --
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertTrue(nextProfiler === SentryTraceProfiler.getCurrentProfiler())

        // -- Act --
        fixture.dateProvider.advance(by: 10)
        try fixture.timerFactory.check()

        // -- Assert --
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 1)
    }

    func testTimeout_whenOldCallbackRunsAfterReplacement_shouldNotStopReplacement() throws {
        // -- Arrange --
        _ = try startTrace()
        let oldTimer = try XCTUnwrap(fixture.timerFactory.overrides)
        let oldCallback = try XCTUnwrap(oldTimer.block)
        fixture.dateProvider.advance(by: 30)
        try fixture.timerFactory.check()
        _ = try startTrace()
        let nextTimer = try XCTUnwrap(fixture.timerFactory.overrides?.timer)

        // -- Act --
        oldCallback(oldTimer.timer)

        // -- Assert --
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertTrue(nextTimer.isValid)
        XCTAssertTrue(nextTimer === _sentry_threadUnsafe_traceProfileTimeoutTimer)
    }

    func testScheduleTimeout_whenOldMainCallbackRunsAfterReplacement_shouldIgnoreIt() throws {
        // -- Arrange --
        fixture.queue.blockBeforeMainBlock = { false }
        defer { fixture.queue.blockBeforeMainBlock = { true } }
        let oldID = try startTrace()
        let oldSetup = try XCTUnwrap(fixture.queue.blockOnMainInvocations.last)
        SentrySDK.internal.profiling.discard(for: oldID)
        _ = try startTrace()
        let nextSetup = try XCTUnwrap(fixture.queue.blockOnMainInvocations.last)

        // -- Act --
        oldSetup()

        // -- Assert --
        XCTAssertFalse(fixture.timerFactory.isTimerInitialized())

        // -- Act --
        nextSetup()

        // -- Assert --
        XCTAssertTrue(fixture.timerFactory.isTimerInitialized())
    }

    func testCollect_whenTimedOutProfilerIsReplaced_shouldKeepItsSamplesAndTimeoutReason() throws {
        // -- Arrange --
        let oldID = try startTrace()
        let oldProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        let oldState = SentryProfilerState()
        oldProfiler.state = oldState
        appendSample(to: oldState, address: 0x1)
        fixture.dateProvider.advance(by: 1)
        appendSample(to: oldState, address: 0x1)
        fixture.dateProvider.advance(by: 29)
        try fixture.timerFactory.check()
        let nextID = try startTrace()
        let nextProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        let nextState = SentryProfilerState()
        nextProfiler.state = nextState
        appendSample(to: nextState, address: 0x2)
        fixture.dateProvider.advance(by: 1)
        appendSample(to: nextState, address: 0x2)

        // -- Act --
        let oldPayload = try XCTUnwrap(SentrySDK.internal.profiling.collect(between: 0, and: 1_000_000_000, for: oldID))

        // -- Assert --
        XCTAssertEqual(oldPayload["truncation_reason"] as? String, "timeout")
        XCTAssertEqual(try addresses(in: oldPayload), [["0x0000000000000001"], ["0x0000000000000001"]])
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(oldProfiler === nextProfiler)
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 1)

        // -- Act --
        let nextPayload = try XCTUnwrap(SentrySDK.internal.profiling.collect(between: 30_000_000_000, and: 31_000_000_000, for: nextID))

        // -- Assert --
        XCTAssertEqual(nextPayload["truncation_reason"] as? String, "normal")
        XCTAssertEqual(try addresses(in: nextPayload), [["0x0000000000000002"], ["0x0000000000000002"]])
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)
    }

    func testCollect_whenTracesShareProfiler_shouldSliceInclusiveBoundariesWithoutClearingSamples() throws {
        // -- Arrange --
        _ = try startTrace()
        let profiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        let state = SentryProfilerState()
        profiler.state = state
        appendSample(to: state, address: 0x0)
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        let firstID = try startTrace()
        appendSample(to: state, address: 0x1)
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        let secondID = try startTrace()
        appendSample(to: state, address: 0x2)
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        appendSample(to: state, address: 0x3)

        // -- Act --
        let first = try XCTUnwrap(SentrySDK.internal.profiling.collect(between: 1, and: 3, for: firstID))
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        appendSample(to: state, address: 0x4)
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        appendSample(to: state, address: 0x5)
        let second = try XCTUnwrap(SentrySDK.internal.profiling.collect(between: 2, and: 4, for: secondID))

        // -- Assert --
        XCTAssertEqual(try addresses(in: first), [["0x0000000000000001"], ["0x0000000000000002"], ["0x0000000000000003"]])
        XCTAssertEqual(try addresses(in: second), [["0x0000000000000002"], ["0x0000000000000003"], ["0x0000000000000004"]])
        for payload in [first, second] {
            let profile = try XCTUnwrap(payload["profile"] as? [String: Any])
            let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])
            XCTAssertEqual(samples.compactMap { $0["elapsed_since_start_ns"] as? String }, ["0", "1", "2"])
            XCTAssertEqual(samples.compactMap { $0["thread_id"] as? String }, ["1", "1", "1"])
        }
        XCTAssertTrue(profiler === SentryTraceProfiler.getCurrentProfiler())
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 1)
        let profile = try XCTUnwrap(state.copyProfilingData()["profile"] as? [String: Any])
        XCTAssertEqual((profile["samples"] as? [Any])?.count, 6)
    }

    func testCollect_whenProfileHasFewerThanTwoSamples_shouldRecordOneLostProfile() throws {
        for sampleCount in 0...1 {
            // -- Arrange --
            let traceID = try startTrace()
            let profiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
            let state = SentryProfilerState()
            profiler.state = state
            if sampleCount == 1 {
                appendSample(to: state, address: 0x1)
            }
            let start = fixture.dateProvider.systemTime()
            fixture.dateProvider.advanceBy(nanoseconds: 1)

            // -- Act --
            let payload = SentrySDK.internal.profiling.collect(between: start, and: fixture.dateProvider.systemTime(), for: traceID)

            // -- Assert --
            XCTAssertNil(payload)
            XCTAssertEqual(fixture.client.recordLostEvents.count, sampleCount + 1)
            let lost = try XCTUnwrap(fixture.client.recordLostEvents.last)
            XCTAssertEqual(lost.category, .profile)
            XCTAssertEqual(lost.reason, .eventProcessor)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)
        }
    }

    func testCollect_whenOnlyOneSampleFallsInsideTrace_shouldRejectSliceAndRecordOneLostProfile() throws {
        // -- Arrange --
        let traceID = try startTrace()
        let state = SentryProfilerState()
        try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state = state
        for _ in 0..<3 {
            appendSample(to: state, address: 0x1)
            fixture.dateProvider.advanceBy(nanoseconds: 1)
        }

        // -- Act --
        let payload = SentrySDK.internal.profiling.collect(between: 2, and: 3, for: traceID)

        // -- Assert --
        XCTAssertNil(payload)
        XCTAssertEqual(fixture.client.recordLostEvents.count, 1)
        XCTAssertEqual(fixture.client.recordLostEvents.first?.category, .profile)
        XCTAssertEqual(fixture.client.recordLostEvents.first?.reason, .eventProcessor)
    }

    func testFinish_whenProfileHasTooFewSamples_shouldCaptureTransactionOnlyOnce() throws {
        // -- Arrange --
        let tracer = profiledTracer(named: "profiled")
        XCTAssertNotNil(tracer.profilerReferenceID)
        let state = SentryProfilerState()
        try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state = state
        appendSample(to: state, address: 0x1)
        fixture.dateProvider.advance(by: 1)

        // -- Act --
        tracer.finish()
        tracer.finish()

        // -- Assert --
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
        let capture = try XCTUnwrap(fixture.client.captureEventWithScopeInvocations.first)
        XCTAssertEqual(capture.event.transaction, "profiled")
        XCTAssertTrue(capture.additionalEnvelopeItems.isEmpty)
        XCTAssertEqual(fixture.client.recordLostEvents.count, 1)
        XCTAssertEqual(fixture.client.recordLostEvents.first?.category, .profile)
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)
    }

    func testFinish_whenProfileHasTwoBoundarySamples_shouldCaptureProfileWithTransactionOnce() throws {
        // -- Arrange --
        let tracer = profiledTracer(named: "profiled")
        let state = SentryProfilerState()
        try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state = state
        appendSample(to: state, address: 0x1)
        fixture.dateProvider.advance(by: 1)
        appendSample(to: state, address: 0x2)

        // -- Act --
        tracer.finish()
        tracer.finish()

        // -- Assert --
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
        let capture = try XCTUnwrap(fixture.client.captureEventWithScopeInvocations.first)
        XCTAssertEqual(capture.additionalEnvelopeItems.count, 1)
        let item = try XCTUnwrap(capture.additionalEnvelopeItems.first)
        XCTAssertEqual(item.header.type, "profile")
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(item.data)) as? [String: Any])
        XCTAssertEqual(payload["truncation_reason"] as? String, "normal")
        XCTAssertEqual(try addresses(in: payload), [["0x0000000000000001"], ["0x0000000000000002"]])
        let transaction = try XCTUnwrap(payload["transaction"] as? [String: Any])
        XCTAssertEqual(transaction["id"] as? String, capture.event.eventId.sentryIdString)
        XCTAssertEqual(transaction["trace_id"] as? String, tracer.traceId.sentryIdString)
        XCTAssertEqual(fixture.client.recordLostEvents.count, 0)
    }

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    func testCollect_whenAppBackgrounds_shouldPreserveBackgroundTruncationReason() throws {
        // -- Arrange --
        let traceID = try startTrace()
        let state = SentryProfilerState()
        try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state = state
        appendSample(to: state, address: 0x1)
        fixture.dateProvider.advanceBy(nanoseconds: 1)
        appendSample(to: state, address: 0x2)
        fixture.notifications.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // -- Act --
        let payload = try XCTUnwrap(SentrySDK.internal.profiling.collect(between: 0, and: 1, for: traceID))

        // -- Assert --
        XCTAssertEqual(payload["truncation_reason"] as? String, "backgrounded")
        XCTAssertEqual(try addresses(in: payload), [["0x0000000000000001"], ["0x0000000000000002"]])
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)
    }
#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK

    func testFinish_whenTimedOutTracerFinishesAfterReplacement_shouldPreserveBothProfiles() throws {
        // -- Arrange --
        let oldTracer = profiledTracer(named: "old")
        let oldState = SentryProfilerState()
        try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state = oldState
        appendSample(to: oldState, address: 0x1)
        fixture.dateProvider.advance(by: 1)
        appendSample(to: oldState, address: 0x1)
        fixture.dateProvider.advance(by: 29)
        try fixture.timerFactory.check()
        let nextTracer = profiledTracer(named: "next")
        let nextProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        let nextState = SentryProfilerState()
        nextProfiler.state = nextState
        appendSample(to: nextState, address: 0x2)
        fixture.dateProvider.advance(by: 1)
        appendSample(to: nextState, address: 0x2)

        // -- Act --
        oldTracer.finish()

        // -- Assert --
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertTrue(nextProfiler === SentryTraceProfiler.getCurrentProfiler())
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 1)

        // -- Act --
        nextTracer.finish()

        // -- Assert --
        let captures = fixture.client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(captures.count, 2)
        for (index, expected) in [("old", "timeout", "0x0000000000000001"), ("next", "normal", "0x0000000000000002")].enumerated() {
            let capture = try XCTUnwrap(captures.element(at: index))
            XCTAssertEqual(capture.event.transaction, expected.0)
            XCTAssertEqual(capture.additionalEnvelopeItems.count, 1)
            let item = try XCTUnwrap(capture.additionalEnvelopeItems.first)
            let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(item.data)) as? [String: Any])
            XCTAssertEqual(payload["truncation_reason"] as? String, expected.1)
            XCTAssertEqual(try addresses(in: payload), [[expected.2], [expected.2]])
        }
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
    }

    func testFinish_whenTimedOutTracerEnds_shouldNotRecordMetricsOnEitherStoppedOrReplacementProfiler() throws {
        // -- Arrange --
        let system = TestSentrySystemWrapper()
        system.overrides.cpuUsage = 10
        system.overrides.memoryFootprintBytes = 100
        system.overrides.cpuEnergyUsage = 100
        SentryMetricProfiler.setSystemWrapperOverride(system)
        defer { SentryMetricProfiler.setSystemWrapperOverride(nil) }
        let oldTracer = profiledTracer(named: "old")
        let oldProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        fixture.dateProvider.advance(by: 30)
        try fixture.timerFactory.check()
        let nextTracer = profiledTracer(named: "next")
        let nextProfiler = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler())
        let oldMetrics = oldProfiler.metricProfiler.serializeTraceProfileMetricsBetween(0, and: UInt64.max)
        let nextMetrics = nextProfiler.metricProfiler.serializeTraceProfileMetricsBetween(0, and: UInt64.max)
        fixture.dateProvider.advance(by: 1)
        system.overrides.cpuUsage = 20
        system.overrides.memoryFootprintBytes = 200
        system.overrides.cpuEnergyUsage = 110

        // -- Act --
        oldTracer.finish()

        // -- Assert --
        XCTAssertEqual(oldProfiler.metricProfiler.serializeTraceProfileMetricsBetween(0, and: UInt64.max), oldMetrics)
        XCTAssertEqual(nextProfiler.metricProfiler.serializeTraceProfileMetricsBetween(0, and: UInt64.max), nextMetrics)
        XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())

        // -- Act --
        nextTracer.finish()

        // -- Assert --
        let metrics = nextProfiler.metricProfiler.serializeTraceProfileMetricsBetween(0, and: UInt64.max)
        let cpu = try XCTUnwrap(metrics["cpu_usage"] as? [String: Any])
        let values = try XCTUnwrap(cpu["values"] as? [[String: Any]])
        XCTAssertEqual(values.compactMap { $0["value"] as? Int }, [10, 20])
        XCTAssertEqual(values.compactMap { $0["elapsed_since_start_ns"] as? String }, ["30000000000", "31000000000"])
    }

    private func profiledTracer(named name: String) -> SentryTracer {
        let configuration = SentryTracerConfiguration()
        configuration.profilesSamplerDecision = SentrySamplerDecision(decision: .yes, forSampleRate: 1, withSampleRand: 0.5)
        let context = TransactionContext(name: name, operation: "test", sampled: .yes, sampleRate: 1, sampleRand: 0.5)
        return SentryTracer(transactionContext: context, hub: fixture.hub, configuration: configuration)
    }

    private func startTrace() throws -> SentryId {
        let traceID = SentryId()
        traceIDs.append(traceID)
        XCTAssertTrue(SentryTraceProfiler.start(withTracer: traceID))
        return traceID
    }

    private func appendSample(to state: SentryProfilerState, address: NSNumber) {
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: 1, threadPriority: 2, threadName: "test", addresses: [address])
    }

    private func addresses(in payload: [String: Any]) throws -> [[String]] {
        let profile = try XCTUnwrap(payload["profile"] as? [String: Any])
        let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])
        let stacks = try XCTUnwrap(profile["stacks"] as? [[Int]])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])
        return try samples.map { sample in
            let index = try XCTUnwrap(sample["stack_id"] as? Int)
            return try XCTUnwrap(stacks.element(at: index)).map { frameIndex in
                let frame = try XCTUnwrap(frames.element(at: frameIndex))
                return try XCTUnwrap(frame["instruction_addr"] as? String)
            }
        }
    }
}
#endif // os(iOS) || os(macOS)
