#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
@_spi(Private) @testable import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import SentryTestUtilsObjC
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjCpp
import XCTest

final class SentryContinuousProfilerTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!
    
    override class func setUp() {
        super.setUp()
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
    }
    
    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }
    
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testSentryProfilerChunkExpirationInterval() {
        XCTAssertEqual(60, kSentryProfilerChunkExpirationInterval)
    }

    func testStartingAndStoppingContinuousProfiler() throws {
        try performContinuousProfilingTest()
    }
    
    func testProfilingDataContainsEnvironmentSetFromOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }
    
    func testProfilingDataContainsEnvironmentSetFromConfigureScope() throws {
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScopeAndOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = "options-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScopeAndOptionsAndEvent() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = "options-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        let event = Event()
        event.environment = "event-environment"
        fixture.hub.capture(event: event)
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

#if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK

#if !SDK_V10
    func testDoesNotStopFramesTracker_WhenAppHangsV2Enabled() throws {
        try performContinuousProfilingTest()

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().framesTracker.isRunning)
    }
#endif // !SDK_V10

    // test that receiving a background notification stops the continuous
    // profiler after it has been started manually
    func testStoppingContinuousProfilerStopsOnBackground() throws {
        SentryContinuousProfiler.start()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification, object: nil))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    #endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK

    /**
     Given a running continuous profiler,
     when time advances past the trace profiler's 30-second timeout but not the chunk boundary,
     then sampling continues and no chunk is transmitted.
     Continuous profiling must not inherit the trace profiler's timeout behavior.
     */
    func testTimer_whenTraceTimeoutHasElapsed_shouldKeepProfilingWithoutTransmittingChunk() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        fixture.currentDateProvider.advanceBy(interval: 31)
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(try XCTUnwrap(fixture.client).captureEnvelopeInvocations.isEmpty)
    }
    
    func testClosingSDKStopsProfile() throws {
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.start()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.close()
        try assertContinuousProfileStoppage()
    }

    func testStartingAPerformanceTransactionDoesNotStartProfiler() throws {
        let manualSpan = try fixture.newTransaction()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        let automaticSpan = try fixture.newTransaction(automaticTransaction: true)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        manualSpan.finish()
        automaticSpan.finish()
    }

    func testStop_whenChunkIsIncomplete_shouldCaptureRemainingSamplesAtChunkEnd() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let state = SentryProfilerState()
        profiler.state = state
        appendControlledSample(to: state, threadID: 1, addresses: [0x1])
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()
        fixture.currentDateProvider.advance(by: 1)
        appendControlledSample(to: state, threadID: 1, addresses: [0x2])

        // -- Act --
        SentryContinuousProfiler.stop()
        fixture.currentDateProvider.advance(by: 58)
        appendControlledSample(to: state, threadID: 1, addresses: [0x3])
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 1)

        // -- Act --
        fixture.currentDateProvider.advance(by: 1)
        appendControlledSample(to: state, threadID: 1, addresses: [0x4])
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 2)
        let firstProfile = try XCTUnwrap(try capturedChunk(at: 0)["profile"] as? [String: Any])
        let lastProfile = try XCTUnwrap(try capturedChunk(at: 1)["profile"] as? [String: Any])
        XCTAssertEqual(try sampleAddresses(in: firstProfile), [["0x0000000000000001"]])
        XCTAssertEqual(try sampleAddresses(in: lastProfile), [
            ["0x0000000000000002"], ["0x0000000000000003"], ["0x0000000000000004"]
        ])
    }
    
    /**
     Given a running profiler whose serialization queue is paused,
     when a chunk boundary is reached,
     then serialization is queued and no envelope is captured until that work executes.
     Executing the queued work captures one profile chunk without stopping sampling.
     This checks deferred dispatch, not which thread executes the work in production.
     */
    func testTransmitChunk_whenSerializationIsDeferred_shouldQueueSerialization() throws {
        // -- Arrange --
        let client = try XCTUnwrap(fixture.client)
        SentryContinuousProfiler.start()
        let originalAsyncExecution = fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock
        defer {
            fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = originalAsyncExecution
            SentryContinuousProfiler.stop()
            do {
                try assertContinuousProfileStoppage()
            } catch {
                XCTFail("Failed to stop continuous profiler: \(error)")
            }
        }
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        let currentAsyncDispatches = fixture.dispatchQueueWrapper.dispatchAsyncCalled

        // -- Act --
        fixture.currentDateProvider.advanceBy(interval: 60)
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertTrue(client.captureEnvelopeInvocations.isEmpty)
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncCalled, currentAsyncDispatches + 1)

        // -- Act --
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = true
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 1)
        let envelope = try XCTUnwrap(client.captureEnvelopeInvocations.first)
        let profileItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual("profile_chunk", profileItem.header.type)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    /**
     Given a stop request waiting for the current chunk to finish,
     when profiling starts again before that boundary,
     then the pending stop is canceled and the same profiler, timer, and correlation ID remain.
     A later stop request still transmits the final chunk and shuts down profiling.
     */
    func testStart_whenStopIsPending_shouldKeepSameProfilerRunning() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        let initialProfiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let initialTimer = try XCTUnwrap(fixture.timeoutTimerFactory.overrides?.timer)

        // -- Act --
        fixture.currentDateProvider.advanceBy(interval: 1)
        SentryContinuousProfiler.stop()

        fixture.currentDateProvider.advanceBy(interval: 1)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        fixture.currentDateProvider.advanceBy(interval: 1)
        SentryContinuousProfiler.start()

        fixture.currentDateProvider.advanceBy(interval: 60)
        try fixture.timeoutTimerFactory.check()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        fixture.currentDateProvider.advanceBy(interval: 1)
        SentryContinuousProfiler.stop()

        // -- Assert --
        XCTAssertTrue(initialProfiler === SentryContinuousProfiler.profiler())
        XCTAssertTrue(initialTimer === fixture.timeoutTimerFactory.overrides?.timer)
        let firstEnvelope = try XCTUnwrap(fixture.client?.captureEnvelopeInvocations.first)
        let firstItem = try XCTUnwrap(firstEnvelope.items.first)
        let firstChunk = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(firstItem.data)) as? [String: Any])
        XCTAssertEqual(firstChunk["profiler_id"] as? String, initialProfiler.profilerId.sentryIdString)
        fixture.currentDateProvider.advanceBy(interval: 60)
        try fixture.timeoutTimerFactory.check()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 2)
    }
    
    func testTransmitChunkEnvelopeWithNilProfiler() throws {
        // Arrange
        // Ensure no profiler is currently running
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        
        // Act
        SentryContinuousProfiler.transmitChunkEnvelope()
        
        // Assert
        // The function should handle nil profiler gracefully:
        // 1. Should not crash when no profiler is running
        // 2. Should return early and log a debug message
        // 3. Should not attempt to capture any envelopes
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(fixture.client?.captureEnvelopeInvocations.isEmpty ?? true)
    }
    
    /**
     Given collected samples and debug-image metadata that cannot be serialized to JSON,
     when chunk serialization fails,
     then no envelope is captured and profiling continues.
     When valid metadata and new samples are available for the next chunk,
     then that chunk is captured, proving one serialization failure does not disable delivery.
     */
    func testTransmitChunk_whenSerializationFails_shouldKeepProfilingAndCaptureNextChunk() throws {
        // -- Arrange --
        class UnserializableDebugMeta: DebugMeta {
            override func serialize() -> [String: Any] {
                // Inject a failing collaborator output without replacing the JSON serializer.
                return ["image_addr": NSObject()]
            }
        }
        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = [UnserializableDebugMeta()]
        let container = SentryDependencyContainer.sharedInstance()
        let originalDebugImageProvider = container.debugImageProvider
        container.debugImageProvider = debugImageProvider
        defer { container.debugImageProvider = originalDebugImageProvider }
        let client = try XCTUnwrap(fixture.client)
        SentryContinuousProfiler.start()
        defer {
            SentryContinuousProfiler.stop()
            do {
                try assertContinuousProfileStoppage()
            } catch {
                XCTFail("Failed to stop continuous profiler: \(error)")
            }
        }
        try addMockSamples(mockAddresses: [0x1, 0x2])

        // -- Act --
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertEqual(debugImageProvider.getDebugImagesFromCacheInvocations.count, 1)
        XCTAssertTrue(client.captureEnvelopeInvocations.isEmpty)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        debugImageProvider.debugImages = []
        try addMockSamples(mockAddresses: [0x3, 0x4])
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 1)
        let envelope = try XCTUnwrap(client.captureEnvelopeInvocations.first)
        XCTAssertEqual(envelope.items.first?.header.type, "profile_chunk")
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

// MARK: Chunk contents
extension SentryContinuousProfilerTests {
    func testTransmitChunk_whenStacksOverlap_shouldDeduplicateAndResetChunkLocalTables() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        // Isolate collected data from unrelated native sampler callbacks.
        let state = SentryProfilerState()
        profiler.state = state
        fixture.currentDateProvider.setDate(date: Date(timeIntervalSince1970: 1_000))
        appendControlledSample(to: state, threadID: 1, addresses: [0x1, 0x2])
        appendControlledSample(to: state, threadID: 2, addresses: [0x3, 0x2])
        appendControlledSample(to: state, threadID: 1, addresses: [0x1, 0x2])

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()
        let firstChunk = try capturedChunk(at: 0)
        appendControlledSample(to: state, threadID: 2, addresses: [0x2, 0x4])
        SentryContinuousProfiler.transmitChunkEnvelope()
        let secondChunk = try capturedChunk(at: 1)

        // -- Assert --
        let firstProfile = try XCTUnwrap(firstChunk["profile"] as? [String: Any])
        let firstFrames = try XCTUnwrap(firstProfile["frames"] as? [[String: Any]])
        XCTAssertEqual(firstFrames.count, 3)
        XCTAssertEqual(firstFrames.compactMap { $0["instruction_addr"] as? String }, [
            "0x0000000000000001", "0x0000000000000002", "0x0000000000000003"
        ])
        XCTAssertEqual(firstProfile["stacks"] as? [[Int]], [[0, 1], [2, 1]])
        let firstSamples = try XCTUnwrap(firstProfile["samples"] as? [[String: Any]])
        XCTAssertEqual(firstSamples.count, 3)
        XCTAssertEqual(firstSamples.compactMap { $0["stack_id"] as? Int }, [0, 1, 0])
        XCTAssertEqual(firstSamples.compactMap { $0["thread_id"] as? String }, ["1", "2", "1"])
        XCTAssertEqual(firstSamples.compactMap { $0["timestamp"] as? TimeInterval }, [1_000, 1_000, 1_000])

        let secondProfile = try XCTUnwrap(secondChunk["profile"] as? [String: Any])
        let secondFrames = try XCTUnwrap(secondProfile["frames"] as? [[String: Any]])
        XCTAssertEqual(secondFrames.count, 2)
        XCTAssertEqual(secondFrames.compactMap { $0["instruction_addr"] as? String }, [
            "0x0000000000000002", "0x0000000000000004"
        ])
        XCTAssertEqual(secondProfile["stacks"] as? [[Int]], [[0, 1]])
        let secondSamples = try XCTUnwrap(secondProfile["samples"] as? [[String: Any]])
        XCTAssertEqual(secondSamples.count, 1)
        XCTAssertEqual(secondSamples.first?["stack_id"] as? Int, 0)
        XCTAssertEqual(secondSamples.first?["thread_id"] as? String, "2")
        let metadata = try XCTUnwrap(secondProfile["thread_metadata"] as? [String: [String: Any]])
        XCTAssertEqual(Set(metadata.keys), ["2"])
        XCTAssertEqual(metadata["2"]?["name"] as? String, "controlled-2")
        XCTAssertEqual(metadata["2"]?["priority"] as? Int, 2)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testTransmitChunk_whenRotatingChunks_shouldUseUniqueChunkIDsAndStableProfilerID() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()
        SentryContinuousProfiler.transmitChunkEnvelope()
        let firstChunk = try capturedChunk(at: 0)
        let secondChunk = try capturedChunk(at: 1)

        // -- Assert --
        let firstID = try XCTUnwrap(firstChunk["chunk_id"] as? String)
        let secondID = try XCTUnwrap(secondChunk["chunk_id"] as? String)
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertNotEqual(SentryId(uuidString: firstID), SentryId.empty)
        XCTAssertNotEqual(SentryId(uuidString: secondID), SentryId.empty)
        XCTAssertEqual(firstChunk["profiler_id"] as? String, profiler.profilerId.sentryIdString)
        XCTAssertEqual(secondChunk["profiler_id"] as? String, profiler.profilerId.sentryIdString)
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 2)
    }

    func testStart_whenRestartingAfterCleanup_shouldReuseProfilerIDWithNewChunkID() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let firstProfiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        SentryContinuousProfiler.transmitChunkEnvelope()
        SentryContinuousProfiler.stop()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        SentryContinuousProfiler.start()
        let nextProfiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        SentryContinuousProfiler.transmitChunkEnvelope()
        let firstChunk = try capturedChunk(at: 0)
        let nextChunk = try capturedChunk(at: 2)

        // -- Assert --
        XCTAssertFalse(firstProfiler === nextProfiler)
        XCTAssertEqual(firstChunk["profiler_id"] as? String, firstProfiler.profilerId.sentryIdString)
        XCTAssertEqual(nextChunk["profiler_id"] as? String, firstProfiler.profilerId.sentryIdString)
        XCTAssertNotEqual(firstChunk["chunk_id"] as? String, nextChunk["chunk_id"] as? String)
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 3)
    }

    func testTransmitChunk_whenNoSamplesOrOneSample_shouldEncodeCollectedSamples() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let state = SentryProfilerState()
        profiler.state = state

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()
        let emptyChunk = try capturedChunk(at: 0)
        appendControlledSample(to: state, threadID: 1, addresses: [0x1])
        SentryContinuousProfiler.transmitChunkEnvelope()
        let singleSampleChunk = try capturedChunk(at: 1)

        // -- Assert --
        let emptyProfile = try XCTUnwrap(emptyChunk["profile"] as? [String: Any])
        XCTAssertEqual((emptyProfile["samples"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual((emptyProfile["frames"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual(emptyProfile["stacks"] as? [[Int]], [])
        let singleSampleProfile = try XCTUnwrap(singleSampleChunk["profile"] as? [String: Any])
        XCTAssertEqual((singleSampleProfile["samples"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(try sampleAddresses(in: singleSampleProfile), [["0x0000000000000001"]])
    }

    func testTimer_whenSamplesArriveAtChunkBoundary_shouldCaptureEachSampleExactlyOnce() throws {
        // -- Arrange --
        fixture.currentDateProvider.setDate(date: Date(timeIntervalSince1970: 1_000))
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let state = SentryProfilerState()
        profiler.state = state
        fixture.currentDateProvider.advance(by: 59)
        appendControlledSample(to: state, threadID: 1, addresses: [0x1])
        fixture.currentDateProvider.advance(by: 1)
        appendControlledSample(to: state, threadID: 1, addresses: [0x2])

        // -- Act --
        try fixture.timeoutTimerFactory.check()
        appendControlledSample(to: state, threadID: 1, addresses: [0x3])
        fixture.currentDateProvider.advance(by: 60)
        appendControlledSample(to: state, threadID: 1, addresses: [0x4])
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        let firstProfile = try XCTUnwrap(try capturedChunk(at: 0)["profile"] as? [String: Any])
        let secondProfile = try XCTUnwrap(try capturedChunk(at: 1)["profile"] as? [String: Any])
        let firstSamples = try XCTUnwrap(firstProfile["samples"] as? [[String: Any]])
        let secondSamples = try XCTUnwrap(secondProfile["samples"] as? [[String: Any]])
        XCTAssertEqual(firstSamples.compactMap { $0["timestamp"] as? TimeInterval }, [1_059, 1_060])
        XCTAssertEqual(secondSamples.compactMap { $0["timestamp"] as? TimeInterval }, [1_060, 1_120])
        XCTAssertEqual(try sampleAddresses(in: firstProfile), [
            ["0x0000000000000001"], ["0x0000000000000002"]
        ])
        XCTAssertEqual(try sampleAddresses(in: secondProfile), [
            ["0x0000000000000003"], ["0x0000000000000004"]
        ])
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 2)
    }

    func testTransmitChunk_whenSampleArrivesAfterSnapshot_shouldPreserveItForNextChunk() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let state = SampleAfterSnapshotState()
        profiler.state = state
        fixture.currentDateProvider.setDate(date: Date(timeIntervalSince1970: 1_000))
        appendControlledSample(to: state, threadID: 1, addresses: [0x1])
        state.afterSnapshot = { [self, weak state] in
            guard let state else { return }
            appendControlledSample(to: state, threadID: 1, addresses: [0x2])
        }

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()
        SentryContinuousProfiler.transmitChunkEnvelope()

        // -- Assert --
        let firstProfile = try XCTUnwrap(try capturedChunk(at: 0)["profile"] as? [String: Any])
        let secondProfile = try XCTUnwrap(try capturedChunk(at: 1)["profile"] as? [String: Any])
        XCTAssertEqual(try sampleAddresses(in: firstProfile), [["0x0000000000000001"]])
        XCTAssertEqual(try sampleAddresses(in: secondProfile), [["0x0000000000000002"]])
    }
}

// MARK: Deferred lifecycle callbacks
extension SentryContinuousProfilerTests {
    func testTransmitChunk_whenSerializationRunsAfterRestart_shouldCaptureOriginalSnapshots() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let state = SentryProfilerState()
        try XCTUnwrap(SentryContinuousProfiler.profiler()).state = state
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer { fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = true }
        var serializations: [() -> Void] = []
        let stacks: [[NSNumber]] = [[0x1], [0x2]]
        for stack in stacks {
            appendControlledSample(to: state, threadID: 1, addresses: stack)
            SentryContinuousProfiler.transmitChunkEnvelope()
            serializations.append(try XCTUnwrap(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.last))
        }
        SentryContinuousProfiler.stopTimerAndCleanup()
        SentryContinuousProfiler.start()
        let nextState = SentryProfilerState()
        try XCTUnwrap(SentryContinuousProfiler.profiler()).state = nextState
        appendControlledSample(to: nextState, threadID: 1, addresses: [0x3])
        SentryContinuousProfiler.transmitChunkEnvelope()
        serializations.append(try XCTUnwrap(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.last))

        // -- Act --
        serializations.reversed().forEach { $0() }

        // -- Assert --
        let addresses = try (0..<3).map { index in
            try sampleAddresses(in: XCTUnwrap(capturedChunk(at: index)["profile"] as? [String: Any]))
        }
        XCTAssertEqual(addresses, [
            [["0x0000000000000003"]], [["0x0000000000000002"]], [["0x0000000000000001"]]
        ])
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testTransmitChunk_whenCurrentHubChangesBeforeSerialization_shouldUseOriginalHub() throws {
        // -- Arrange --
        fixture.options.releaseName = "original-release"
        fixture.options.environment = "original-environment"
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer { fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = true }
        SentryContinuousProfiler.transmitChunkEnvelope()
        let serialize = try XCTUnwrap(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.last)
        let replacement = SentryProfileTestFixture()
        replacement.options.releaseName = "replacement-release"
        replacement.options.environment = "replacement-environment"
        let replacementImages = TestDebugImageProvider()
        replacementImages.debugImages = []
        SentryDependencyContainer.sharedInstance().debugImageProvider = replacementImages

        // -- Act --
        serialize()

        // -- Assert --
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 1)
        XCTAssertEqual(replacement.client?.captureEnvelopeInvocations.count, 0)
        let chunk = try capturedChunk(at: 0)
        XCTAssertEqual(chunk["release"] as? String, "original-release")
        XCTAssertEqual(chunk["environment"] as? String, "original-environment")
        let debugMeta = try XCTUnwrap(chunk["debug_meta"] as? [String: Any])
        XCTAssertEqual((debugMeta["images"] as? [[String: Any]])?.first?["debug_id"] as? String, "debugID")
    }

    func testTransmitChunk_whenSDKClosesBeforeSerialization_shouldNotSendToReplacementClient() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer { fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = true }
        SentryContinuousProfiler.transmitChunkEnvelope()
        let serialize = try XCTUnwrap(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.last)
        SentrySDK.close()
        let replacement = SentryProfileTestFixture()

        // -- Act --
        serialize()

        // -- Assert --
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 0)
        XCTAssertEqual(replacement.client?.captureEnvelopeInvocations.count, 0)
    }

    func testScheduleTimer_whenProfilerIsReplacedBeforeMainCallback_shouldIgnoreOldCallback() throws {
        // -- Arrange --
        fixture.dispatchQueueWrapper.blockBeforeMainBlock = { false }
        defer { fixture.dispatchQueueWrapper.blockBeforeMainBlock = { true } }
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let oldSetup = try XCTUnwrap(fixture.dispatchQueueWrapper.blockOnMainInvocations.last)
        SentryContinuousProfiler.stopTimerAndCleanup()
        SentryContinuousProfiler.start()
        let newSetup = try XCTUnwrap(fixture.dispatchQueueWrapper.blockOnMainInvocations.last)

        // -- Act --
        oldSetup()

        // -- Assert --
        XCTAssertFalse(fixture.timeoutTimerFactory.isTimerInitialized())

        // -- Act --
        newSetup()

        // -- Assert --
        XCTAssertTrue(fixture.timeoutTimerFactory.isTimerInitialized())
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testTimer_whenCallbackBelongsToStoppedProfiler_shouldNotRotateReplacementChunk() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let oldTimer = try XCTUnwrap(fixture.timeoutTimerFactory.overrides)
        SentryContinuousProfiler.stopTimerAndCleanup()
        SentryContinuousProfiler.start()
        let state = SentryProfilerState()
        try XCTUnwrap(SentryContinuousProfiler.profiler()).state = state
        appendControlledSample(to: state, threadID: 1, addresses: [0x2])

        // -- Act --
        if let callback = oldTimer.block {
            callback(oldTimer.timer)
        } else if let invocation = oldTimer.invocationInfo {
            try Invocation(target: invocation.target, selector: invocation.selector).invoke()
        }

        // -- Assert --
        XCTAssertEqual(fixture.client?.captureEnvelopeInvocations.count, 0)
        try fixture.timeoutTimerFactory.fire()
        let profile = try XCTUnwrap(try capturedChunk(at: 0)["profile"] as? [String: Any])
        XCTAssertEqual(try sampleAddresses(in: profile), [["0x0000000000000002"]])
    }

    func testTimer_whenLogHandlerRestartsProfilerBeforeCleanup_shouldKeepProfiling() throws {
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let originalOutput = SentrySDKLog.getOutput()
        defer { SentrySDKLog.setOutput(originalOutput) }
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
        var restarted = false
        SentrySDKLog.setOutput { message in
            if message.contains("Last continuous profile chunk transmitted after stop called"), !restarted {
                restarted = true
                SentryContinuousProfiler.start()
            }
        }
        SentryContinuousProfiler.stop()

        // -- Act --
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // -- Assert --
        XCTAssertTrue(restarted)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

#if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    func testScheduleTimer_whenAppBackgroundsBeforeMainCallback_shouldNotCreateTimer() throws {
        // -- Arrange --
        fixture.dispatchQueueWrapper.blockBeforeMainBlock = { false }
        defer { fixture.dispatchQueueWrapper.blockBeforeMainBlock = { true } }
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let setup = try XCTUnwrap(fixture.dispatchQueueWrapper.blockOnMainInvocations.last)
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))

        // -- Act --
        setup()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(fixture.timeoutTimerFactory.isTimerInitialized())
    }

    func testBackgroundObserver_whenCallbackBelongsToStoppedProfiler_shouldIgnoreIt() throws {
        // -- Arrange --
        let observerCount = fixture.notificationCenter.observerCount
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        SentryContinuousProfiler.start()
        let oldObserver = try XCTUnwrap(fixture.notificationCenter.addObserverWithBlockInvocations.last)
        SentryContinuousProfiler.stopTimerAndCleanup()
        XCTAssertEqual(fixture.notificationCenter.observerCount, observerCount)
        SentryContinuousProfiler.start()
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let timer = try XCTUnwrap(fixture.timeoutTimerFactory.overrides?.timer)

        // -- Act --
        oldObserver.block(Notification(name: UIApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(profiler === SentryContinuousProfiler.profiler())
        XCTAssertEqual(fixture.notificationCenter.observerCount, observerCount + 1)
        SentryContinuousProfiler.stopTimerAndCleanup()
        XCTAssertFalse(timer.isValid)
        XCTAssertEqual(fixture.notificationCenter.observerCount, observerCount)
    }
#endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
}

// Models a sampler callback immediately after snapshot collection releases its lock.
private final class SampleAfterSnapshotState: SentryProfilerState {
    var afterSnapshot: (() -> Void)?

    override func copyProfilingData() -> [String: Any] {
        let snapshot = super.copyProfilingData()
        appendPendingSample()
        return snapshot
    }

    override func copyAndClearProfilingData() -> [String: Any] {
        let snapshot = super.copyAndClearProfilingData()
        appendPendingSample()
        return snapshot
    }

    private func appendPendingSample() {
        let callback = afterSnapshot
        afterSnapshot = nil
        callback?()
    }
}

private extension SentryContinuousProfilerTests {
    func appendControlledSample(to state: SentryProfilerState, threadID: UInt64, addresses: [NSNumber]) {
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(
            to: state, threadID: threadID, threadPriority: 2,
            threadName: "controlled-\(threadID)", addresses: addresses
        )
    }

    func capturedChunk(at index: Int) throws -> [String: Any] {
        let envelope = try XCTUnwrap(fixture.client?.captureEnvelopeInvocations.invocations.element(at: index))
        XCTAssertEqual(envelope.items.count, 1)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.type, "profile_chunk")
        let data = try XCTUnwrap(item.data)
        let chunk = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(chunk["chunk_id"] as? String, envelope.header.eventId?.sentryIdString)
        return chunk
    }

    func sampleAddresses(in profile: [String: Any]) throws -> [[String]] {
        let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])
        let stacks = try XCTUnwrap(profile["stacks"] as? [[Int]])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])
        return try samples.map { sample in
            let stackID = try XCTUnwrap(sample["stack_id"] as? Int)
            let stack = try XCTUnwrap(stacks.element(at: stackID))
            return try stack.map { frameIndex in
                let frame = try XCTUnwrap(frames.element(at: frameIndex))
                return try XCTUnwrap(frame["instruction_addr"] as? String)
            }
        }
    }

    func addMockSamples(mockAddresses: [NSNumber]) throws {
        let mockThreadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "main")
        let state = try XCTUnwrap(SentryContinuousProfiler.profiler()?.state)
        for _ in 0..<Int(60) {
            fixture.currentDateProvider.advanceBy(interval: 1)
            SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: mockThreadMetadata.id, threadPriority: mockThreadMetadata.priority, threadName: mockThreadMetadata.name, addresses: mockAddresses)
        }
    }
    
    func performContinuousProfilingTest(expectedEnvironment: String = Options.defaultEnvironment) throws {
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.start()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        
        func runTestPart(expectedAddresses: [NSNumber], mockMetrics: SentryProfileTestFixture.MockMetric, countMetricsReadingAtProfileStart: Bool = true) throws {
            fixture.setMockMetrics(mockMetrics)
            try addMockSamples(mockAddresses: expectedAddresses)
            try fixture.gatherMockedContinuousProfileMetrics()
            try addMockSamples(mockAddresses: expectedAddresses)
            fixture.currentDateProvider.advanceBy(interval: 1)
            try fixture.timeoutTimerFactory.check()
            XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
            try assertValidData(expectedEnvironment: expectedEnvironment, expectedAddresses: expectedAddresses, countMetricsReadingAtProfileStart: countMetricsReadingAtProfileStart)
    #if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
            fixture.resetProfileGPUExpectations()
    #endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
            fixture.currentDateProvider.advanceBy(interval: 1)
        }
        
        try runTestPart(expectedAddresses: [0x1, 0x2, 0x3], mockMetrics: SentryProfileTestFixture.MockMetric())
        try runTestPart(expectedAddresses: [0x4, 0x5, 0x6], mockMetrics: SentryProfileTestFixture.MockMetric(cpuUsage: 1.23, memoryFootprint: 456, cpuEnergyUsage: 7), countMetricsReadingAtProfileStart: false)
        try runTestPart(expectedAddresses: [0x7, 0x8, 0x9], mockMetrics: SentryProfileTestFixture.MockMetric(cpuUsage: 9.87, memoryFootprint: 654, cpuEnergyUsage: 3), countMetricsReadingAtProfileStart: false)
        
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.stop()
        try assertContinuousProfileStoppage()
    }
    
    func assertContinuousProfileStoppage() throws {
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    func assertValidData(expectedEnvironment: String, expectedAddresses: [NSNumber], countMetricsReadingAtProfileStart: Bool = true) throws {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEnvelopeInvocations.last)
        XCTAssertEqual(1, envelope.items.count)
        let profileItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual("profile_chunk", profileItem.header.type)
        XCTAssertEqual("cocoa", profileItem.header.platform)
        let data = try XCTUnwrap(profileItem.data)
        let profile = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(try XCTUnwrap(profile["version"] as? String), "2")

        let platform = try XCTUnwrap(profile["platform"] as? String)
        XCTAssertEqual("cocoa", platform)

        XCTAssertEqual(expectedEnvironment, try XCTUnwrap(profile["environment"] as? String))

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let expectedReleaseString = "\(bundleID)@\(version)+\(build)"
        let actualReleaseString = try XCTUnwrap(profile["release"] as? String)
        XCTAssertEqual(actualReleaseString, expectedReleaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: try XCTUnwrap(profile["profiler_id"] as? String)))

        let debugMeta = try XCTUnwrap(profile["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
        let firstImage = try XCTUnwrap(images.first)
        XCTAssertFalse(try XCTUnwrap(firstImage["code_file"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["debug_id"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["image_addr"] as? String).isEmpty)
        XCTAssertGreaterThan(try XCTUnwrap(firstImage["image_size"] as? Int), 0)
        XCTAssertEqual(try XCTUnwrap(firstImage["type"] as? String), "macho")
        
        let clientInfo = try XCTUnwrap(profile["client_sdk"] as? [String: String])
        XCTAssertEqual(try XCTUnwrap(clientInfo["name"]), SentryMeta.sdkName)
        XCTAssertEqual(try XCTUnwrap(clientInfo["version"]), SentryMeta.versionString)

        let sampledProfile = try XCTUnwrap(profile["profile"] as? [String: Any])
        let threadMetadata = try XCTUnwrap(sampledProfile["thread_metadata"] as? [String: [String: Any]])
        XCTAssertFalse(threadMetadata.isEmpty)
        XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
        XCTAssertFalse(try threadMetadata.values.compactMap { $0["name"] }.filter { try XCTUnwrap($0 as? String) == "main" }.isEmpty)

        let samples = try XCTUnwrap(sampledProfile["samples"] as? [[String: Any]])
        XCTAssertFalse(samples.isEmpty)

        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames.first?["instruction_addr"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames.first?["function"] as? String).isEmpty)

        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        var foundAtLeastOneNonEmptySample = false
        XCTAssertFalse(stacks.isEmpty)
        for stack in stacks {
            guard !stack.isEmpty else { continue }
            foundAtLeastOneNonEmptySample = true
            for frameIdx in stack {
                XCTAssertNotNil(frames.element(at: frameIdx))
            }
        }
        XCTAssertTrue(foundAtLeastOneNonEmptySample)

        for sample in samples {
            XCTAssertNotNil(sample["timestamp"] as? NSNumber)
            XCTAssertNotNil(sample["thread_id"])
            let stackIDEntry = try XCTUnwrap(sample["stack_id"])
            let stackID = try XCTUnwrap(stackIDEntry as? Int)
            XCTAssertNotNil(stacks.element(at: stackID))
        }

        let addresses = try sampleAddresses(in: sampledProfile)
        let injectedAddresses = zip(samples, addresses).compactMap { sample, stackAddresses in
            sample["thread_id"] as? String == "1" ? stackAddresses : nil
        }
        let expectedStack = expectedAddresses.map { String(format: "0x%016llx", $0.uint64Value) }
        XCTAssertEqual(injectedAddresses, Array(repeating: expectedStack, count: 120))

        let measurements = try XCTUnwrap(profile["measurements"] as? [String: Any])

        let chunkStartTime = try XCTUnwrap(samples.first?["timestamp"] as? TimeInterval)
        let chunkEndTime = try XCTUnwrap(samples.last?["timestamp"] as? TimeInterval)
 
        // the metric profiler takes a reading right at the start of a profile, so we also get that in addition to the ones that are mocked in these tests
        let expectedReadingsPerBatch = fixture.mockMetrics.readingsPerBatch + (countMetricsReadingAtProfileStart ? 1 : 0)
        
        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUUsage, expectedValue: fixture.mockMetrics.cpuUsage, expectedUnits: kSentryMetricProfilerSerializationUnitPercentage, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch)

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, expectedValue: fixture.mockMetrics.memoryFootprint, expectedUnits: kSentryMetricProfilerSerializationUnitBytes, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch)

        #if arch(arm) || arch(arm64)
        // we wind up with one less energy reading for the first chunk's metric sample. since we must use the difference between readings to get actual values, the first one is only the baseline reading.
        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUEnergyUsage, expectedValue: fixture.mockMetrics.cpuEnergyUsage, expectedUnits: kSentryMetricProfilerSerializationUnitNanoJoules, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch, expectOneLessEnergyReading: countMetricsReadingAtProfileStart)
        #endif // arch(arm) || arch(arm64)

#if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, expectedEntries: fixture.expectedContinuousProfileSlowFrames, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, expectedEntries: fixture.expectedContinuousProfileFrozenFrames, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, expectedEntries: fixture.expectedContinuousProfileFrameRateChanges, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
#else
        XCTAssertNil(measurements[kSentryProfilerSerializationKeySlowFrameRenders])
        XCTAssertNil(measurements[kSentryProfilerSerializationKeyFrozenFrameRenders])
        XCTAssertNil(measurements[kSentryProfilerSerializationKeyFrameRates])
#endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    }
    
    func assertMetricEntries(measurements: [String: Any], key: String, expectedEntries: [[String: Any]], chunkStartTime: TimeInterval, chunkEndTime: TimeInterval) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let actualEntries = try XCTUnwrap(metricContainer["values"] as? [[String: NSNumber]])
        let sortedActualEntries = try sortedByTimestamps(actualEntries)
        let sortedExpectedEntries = try sortedByTimestamps(expectedEntries)

        guard actualEntries.count == expectedEntries.count else {
            XCTFail("Wrong number of values under \(key). expected: \(try printTimestamps(entries: sortedExpectedEntries)); actual: \(try printTimestamps(entries: sortedActualEntries)); chunk start time: \(chunkStartTime)")
            return
        }

        for i in 0..<actualEntries.count {
            let actualEntry = sortedActualEntries[i]
            let expectedEntry = sortedExpectedEntries[i]

            let actualTimestamp = try XCTUnwrap(actualEntry["timestamp"] as? TimeInterval)
            let expectedTimestamp = try XCTUnwrap(expectedEntry["timestamp"] as? TimeInterval)
            XCTAssertEqual(actualTimestamp, expectedTimestamp)
            try assertTimestampOccursWithinTransaction(timestamp: actualTimestamp, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)

            let actualValue = try XCTUnwrap(actualEntry["value"] as? NSNumber)
            let expectedValue = try XCTUnwrap(expectedEntry["value"] as? NSNumber)
            XCTAssertEqual(actualValue, expectedValue)
        }
    }
    
    func sortedByTimestamps(_ entries: [[String: Any]]) throws -> [[String: Any]] {
        try entries.sorted { a, b in
            try XCTUnwrap(a["timestamp"] as? TimeInterval) < XCTUnwrap(b["timestamp"] as? TimeInterval)
        }
    }
    
    func printTimestamps(entries: [[String: Any]]) throws -> [String] {
        try entries.reduce(into: [String](), { partialResult, entry in
            partialResult.append(String(try XCTUnwrap(entry["timestamp"] as? TimeInterval)))
        })
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, expectedValue: T? = nil, expectedUnits: String, chunkStartTime: TimeInterval, chunkEndTime: TimeInterval, readingsPerBatch: Int, expectOneLessEnergyReading: Bool = false) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let values = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, readingsPerBatch - (expectOneLessEnergyReading ? 1 : 0), "Wrong number of values under \(key); (expectOneLessEnergyReading: \(expectOneLessEnergyReading))")

        if let expectedValue = expectedValue {
            let actualValue = try XCTUnwrap(try XCTUnwrap(values.element(at: 1))["value"] as? T)
            XCTAssertEqual(actualValue, expectedValue, "Wrong value for \(key)")

            let timestamp = try XCTUnwrap(values.first?["timestamp"] as? TimeInterval)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)

            let actualUnits = try XCTUnwrap(metricContainer["unit"] as? String)
            XCTAssertEqual(actualUnits, expectedUnits)
        }
    }
    
    /// Assert that the absolute timestamp actually falls within the chunk's duration, so it should be between 0 and the chunk duration.
    func assertTimestampOccursWithinTransaction(timestamp: TimeInterval, chunkStartTime: TimeInterval, chunkEndTime: TimeInterval) throws {
        XCTAssertGreaterThanOrEqual(timestamp, 0)
        XCTAssertLessThanOrEqual(timestamp, chunkEndTime)
    }
}

#endif
