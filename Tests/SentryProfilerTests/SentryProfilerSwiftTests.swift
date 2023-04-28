import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
class SentryProfilerSwiftTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryProfilerSwiftTests")

    private class Fixture {
        lazy var options: Options = {
            let options = Options()
            options.dsn = SentryProfilerSwiftTests.dsnAsString
            return options
        }()
        lazy var client: TestClient? = TestClient(options: options)
        lazy var hub: SentryHub = {
            let hub = SentryHub(client: client, andScope: scope)
            hub.bindClient(client)
            Dynamic(hub).tracesSampler.random = TestRandom(value: 1.0)
            Dynamic(hub).profilesSampler.random = TestRandom(value: 0.5)
            return hub
        }()
        let scope = Scope()
        let message = "some message"
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"

        lazy var systemWrapper = TestSentrySystemWrapper()
        lazy var processInfoWrapper = TestSentryNSProcessInfoWrapper()
        lazy var dispatchFactory = TestDispatchFactory()
        var metricTimerFactory: TestDispatchSourceWrapper?
        lazy var timeoutTimerFactory = TestSentryNSTimerFactory()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        let currentDateProvider = TestCurrentDateProvider()

#if !os(macOS)
        lazy var displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: currentDateProvider)
        lazy var framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
#endif

        init() {
            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
            options.profilesSampleRate = 1.0
            options.tracesSampleRate = 1.0

            SentryDependencyContainer.sharedInstance().systemWrapper = systemWrapper
            SentryDependencyContainer.sharedInstance().processInfoWrapper = processInfoWrapper
            dispatchFactory.vendedSourceHandler = { eventHandler in
                self.metricTimerFactory = eventHandler
            }
            SentryDependencyContainer.sharedInstance().dispatchFactory = dispatchFactory
            SentryDependencyContainer.sharedInstance().timerFactory = timeoutTimerFactory

            systemWrapper.overrides.cpuUsagePerCore = SentryCPUUsagePerCore(usages: mockCPUUsages.map { NSNumber(value: $0) })
            processInfoWrapper.overrides.processorCount = UInt(mockCPUUsages.count)
            systemWrapper.overrides.memoryFootprintBytes = mockMemoryFootprint

#if !os(macOS)
            SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
            framesTracker.start()
            displayLinkWrapper.call()
#endif
        }

        /// Advance the mock date provider, start a new transaction and return its handle.
        func newTransaction(testingAppLaunchSpans: Bool = false, automaticTransaction: Bool = false, idleTimeout: TimeInterval? = nil) throws -> SentryTracer {
            let operation = testingAppLaunchSpans ? SentrySpanOperationUILoad : transactionOperation

            if automaticTransaction {
                return hub.startTransaction(
                    with: TransactionContext(name: transactionName, operation: operation),
                    bindToScope: false,
                    customSamplingContext: [:],
                    configuration: SentryTracerConfiguration(block: {
                        if let idleTimeout = idleTimeout {
                            $0.idleTimeout = idleTimeout
                        }
                        $0.dispatchQueueWrapper = self.dispatchQueueWrapper
                        $0.waitForChildren = true
                        $0.timerFactory = self.timeoutTimerFactory
                    }))
            }

            return try XCTUnwrap(hub.startTransaction(name: transactionName, operation: operation) as? SentryTracer)
        }

        // mocking

        let mockCPUUsages = [12.4, 63.5, 1.4, 4.6]
        let mockMemoryFootprint: SentryRAMBytes = 123_455
        let mockUsageReadingsPerBatch = 2

#if !os(macOS)
        // SentryFramesTracker starts assuming a frame rate of 60 Hz and will only log an update if it changes, so the first value here needs to be different for it to register.
        let mockFrameRateChangesPerBatch: [FrameRate] = [.high, .low, .high, .low]
#endif

#if !os(macOS)
        // Absolute timestamps must be adjusted per span when asserting
        var expectedSlowFrames = [[String: Any]]()
        var expectedFrozenFrames = [[String: Any]]()
        var expectedFrameRateChanges = [[String: Any]]()

        func resetGPUExpectations() {
            expectedSlowFrames = [[String: Any]]()
            expectedFrozenFrames = [[String: Any]]()
            expectedFrameRateChanges = [[String: Any]]()
        }
#endif

        func gatherMockedMetrics(span: Span) throws {
            // clear out any errors that might've been set in previous calls
            systemWrapper.overrides.cpuUsageError = nil
            systemWrapper.overrides.memoryFootprintError = nil

            // gather mock cpu usages and memory footprints
            for _ in 0..<mockUsageReadingsPerBatch {
                self.metricTimerFactory?.fire()
            }

    #if !os(macOS)
            var shouldRecordFrameRateExpectation = true

            func changeFrameRate(_ new: FrameRate) {
                displayLinkWrapper.changeFrameRate(new)
                shouldRecordFrameRateExpectation = true
            }

            func renderGPUFrame(_ type: GPUFrame) {
                switch type {
                case .normal:
                    let currentSystemTime: UInt64 = currentDateProvider.systemTime()
                    print("expect normal frame to start at \(currentSystemTime)")
                    displayLinkWrapper.normalFrame()
                case .slow:
                    let duration = displayLinkWrapper.middlingSlowFrame().toNanoSeconds()
                    let currentSystemTime = currentDateProvider.systemTime()
                    print("will expect \(String(describing: type)) frame starting at \(currentSystemTime)")
                    expectedSlowFrames.append([
                        "elapsed_since_start_ns": String(currentSystemTime),
                        "value": duration
                    ])
                case .frozen:
                    let duration = displayLinkWrapper.fastestFrozenFrame().toNanoSeconds()
                    let currentSystemTime = currentDateProvider.systemTime()
                    print("will expect \(String(describing: type)) frame starting at \(currentSystemTime)")
                    expectedFrozenFrames.append([
                        "elapsed_since_start_ns": String(currentSystemTime),
                        "value": duration
                    ])
                }
                if shouldRecordFrameRateExpectation {
                    shouldRecordFrameRateExpectation = false
                    let currentSystemTime = currentDateProvider.systemTime()
                    print("will expect frame rate \(displayLinkWrapper.currentFrameRate.rawValue) at \(currentSystemTime)")
                    expectedFrameRateChanges.append([
                        "elapsed_since_start_ns": String(currentSystemTime),
                        "value": NSNumber(value: displayLinkWrapper.currentFrameRate.rawValue)
                    ])
                }
            }

            /*
             * Mock a series of GPU frame renders of varying quality (normal/slow/frozen) and
             * refresh rate changes. The refresh rate changes ("|") happen at the same time as
             * the frame render they appear above. Time is not to scale; frozen frames last
             * much longer than the lower end of slow frames.
             *
             * refresh rate:  |---60hz--------------|---120hz------|---60hz--------------------------------------|
             * time:          N--S----N--F----------N-N-S--N-F-----N--N--S----N--F----------N--S----N--F----------
             */
            changeFrameRate(.low)
            renderGPUFrame(.normal)
            renderGPUFrame(.slow)
            renderGPUFrame(.normal)
            renderGPUFrame(.frozen)
            renderGPUFrame(.normal)
            changeFrameRate(.high)
            renderGPUFrame(.normal)
            renderGPUFrame(.slow)
            renderGPUFrame(.normal)
            renderGPUFrame(.frozen)
            renderGPUFrame(.normal)
            changeFrameRate(.low)
            renderGPUFrame(.normal)
            renderGPUFrame(.slow)
            renderGPUFrame(.normal)
            renderGPUFrame(.frozen)
            renderGPUFrame(.normal)
            changeFrameRate(.high)
            renderGPUFrame(.normal)
            renderGPUFrame(.slow)
            renderGPUFrame(.normal)
            renderGPUFrame(.frozen)
    #endif

            // mock errors gathering cpu usage and memory footprint and fire a callback for them to ensure they don't add more information to the payload
            systemWrapper.overrides.cpuUsageError = NSError(domain: "test-error", code: 0)
            systemWrapper.overrides.memoryFootprintError = NSError(domain: "test-error", code: 1)
            metricTimerFactory?.fire()
        }

        // app start simulation

        lazy var appStart = currentDateProvider.date()
        var appStartDuration = 0.5
        lazy var appStartEnd = appStart.addingTimeInterval(appStartDuration)

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        func getAppStartMeasurement(type: SentryAppStartType, preWarmed: Bool = false) -> SentryAppStartMeasurement {
            let runtimeInitDuration = 0.05
            let runtimeInit = appStart.addingTimeInterval(runtimeInitDuration)
            let mainDuration = 0.15
            let main = appStart.addingTimeInterval(mainDuration)
            let didFinishLaunching = appStart.addingTimeInterval(0.3)
            appStart = preWarmed ? main : appStart
            appStartDuration = preWarmed ? appStartDuration - runtimeInitDuration - mainDuration : appStartDuration
            appStartEnd = appStart.addingTimeInterval(appStartDuration)
            return SentryAppStartMeasurement(type: type, isPreWarmed: preWarmed, appStartTimestamp: appStart, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main, didFinishLaunchingTimestamp: didFinishLaunching)
        }
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }

    private var fixture: Fixture!

    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()

        // If a test early exits because of a thrown error, it may not finish the spans it created. This ensures the profiler stops before starting the next test case.
        fixture.timeoutTimerFactory.fire()

        clearTestState()
    }

    func testMetricProfiler() throws {
        let span = try fixture.newTransaction()
        addMockSamples()
        try fixture.gatherMockedMetrics(span: span)
        self.fixture.currentDateProvider.advanceBy(nanoseconds: 1.toNanoSeconds())
        span.finish()
        try self.assertMetricsPayload()
    }

    func testConcurrentProfilingTransactions() throws {
        let numberOfTransactions = 10
        var spans = [Span]()

        func createConcurrentSpansWithMetrics() throws {
            XCTAssertFalse(SentryProfiler.isCurrentlyProfiling())
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))

            for i in 0 ..< numberOfTransactions {
                let span = try fixture.newTransaction()
                XCTAssertTrue(SentryProfiler.isCurrentlyProfiling())
                XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(i + 1))
                spans.append(span)
                fixture.currentDateProvider.advanceBy(nanoseconds: 100)
            }

            addMockSamples()

            for (i, span) in spans.enumerated() {
                try fixture.gatherMockedMetrics(span: span)
                XCTAssertTrue(SentryProfiler.isCurrentlyProfiling())
                span.finish()
                XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(numberOfTransactions - i - 1))

                try self.assertValidProfileData()
                try self.assertMetricsPayload(metricsBatches: i + 1)
            }
            
            XCTAssertFalse(SentryProfiler.isCurrentlyProfiling())
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        }

        try createConcurrentSpansWithMetrics()

        // do everything again to make sure that stopping and starting the profiler over again works
        spans.removeAll()
#if !os(macOS)
        fixture.resetGPUExpectations()
        fixture.displayLinkWrapper.call()
#endif

        try createConcurrentSpansWithMetrics()
    }

    /// Test a situation where a long-running span starts the profiler, which winds up timing out, and then another span starts that begins a new profile, then finishes, and then the long-running span finishes; both profiles should be separately captured in envelopes.
    /// ```
    ///                        time->
    ///    transaction A       |---------------------------------------------------|
    ///    profiler A          |---------------------------x  <- timeout
    ///    transaction B                                           |-------|
    ///    profiler B                                              |-------|  <- normal finish
    ///   ```
    func testConcurrentSpansWithTimeout() throws {
        // start span A and mock profile data for it
        let spanA = try fixture.newTransaction()
        fixture.currentDateProvider.advanceBy(nanoseconds: 1.toNanoSeconds())
        let expectedAddressesA: [NSNumber] = [0x1, 0x2, 0x3]
        let expectedThreadMetadataA = ThreadMetadata(id: 1, priority: 2, name: "test-thread1")
        let expectedQueueMetadataA = QueueMetadata(address: 3, label: "test-queue1")
        addMockSamples(threadMetadata: expectedThreadMetadataA, queueMetadata: expectedQueueMetadataA, addresses: expectedAddressesA)

        // time out profiler for span A
        fixture.currentDateProvider.advanceBy(nanoseconds: 30.toNanoSeconds())
        fixture.timeoutTimerFactory.fire()

        fixture.currentDateProvider.advanceBy(nanoseconds: 0.5.toNanoSeconds())

        // start span B and mock profile data for it
        let spanB = try fixture.newTransaction()
        fixture.currentDateProvider.advanceBy(nanoseconds: 0.5.toNanoSeconds())
        let expectedAddressesB: [NSNumber] = [0x7, 0x8, 0x9]
        let expectedThreadMetadataB = ThreadMetadata(id: 4, priority: 5, name: "test-thread2")
        let expectedQueueMetadataB = QueueMetadata(address: 6, label: "test-queue2")
        addMockSamples(threadMetadata: expectedThreadMetadataB, queueMetadata: expectedQueueMetadataB, addresses: expectedAddressesB)

        // finish span B and check profile data
        spanB.finish()
        try self.assertValidProfileData(expectedAddresses: expectedAddressesB, expectedThreadMetadata: [expectedThreadMetadataB], expectedQueueMetadata: [expectedQueueMetadataB])

        // finish span A and check profile data
        spanA.finish()
        try self.assertValidProfileData(expectedAddresses: expectedAddressesA, expectedThreadMetadata: [expectedThreadMetadataA], expectedQueueMetadata: [expectedQueueMetadataA])
    }

    func testProfileTimeoutTimer() throws {
        try performTest(shouldTimeOut: true)
    }

    func testStartTransaction_ProfilingDataIsValid() throws {
        try performTest()
    }

    func testProfilingDataContainsEnvironmentSetFromOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        try performTest(transactionEnvironment: expectedEnvironment)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testProfileWithTransactionContainingStartupSpansForColdStart() throws {
        try performTest(uikitParameters: UIKitParameters(launchType: .cold, prewarmed: false))
    }

    func testProfileWithTransactionContainingStartupSpansForWarmStart() throws {
        try performTest(uikitParameters: UIKitParameters(launchType: .warm, prewarmed: false))
    }

    func testProfileWithTransactionContainingStartupSpansForPrewarmedStart() throws {
        try performTest(uikitParameters: UIKitParameters(launchType: .cold, prewarmed: true))
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testProfilingDataContainsEnvironmentSetFromConfigureScope() throws {
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performTest(transactionEnvironment: expectedEnvironment)
    }

    func testStartTransaction_NotSamplingProfileUsingEnableProfiling() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = false
        }
    }

    func testStartTransaction_SamplingProfileUsingEnableProfiling() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = true
        }
    }

    func testStartTransaction_NotSamplingProfileUsingSampleRate() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = 0.49
        }
    }

    func testStartTransaction_SamplingProfileUsingSampleRate() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampleRate = 0.5
        }
    }

    func testStartTransaction_SamplingProfileUsingProfilesSampler() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampler = { _ in return 0.51 }
        }
    }

    func testStartTransaction_WhenProfilesSampleRateAndProfilesSamplerNil() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = nil
            options.profilesSampler = { _ in return nil }
        }
    }

    func testStartTransaction_WhenProfilesSamplerOutOfRange_TooBig() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return 1.01 }
        }
    }

    func testStartTransaction_WhenProfilesSamplersOutOfRange_TooSmall() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return -0.01 }
        }
    }

    /// based on ``SentryTracerTests.testFinish_WithoutHub_DoesntCaptureTransaction``
    func testProfilerCleanedUpAfterTransactionDiscarded_NoHub() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() {
            let sut = SentryTracer(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), hub: nil)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
            sut.finish()
        }
        performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testFinish_WaitForAllChildren_ExceedsMaxDuration_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_ExceedsMaxDuration() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    func testProfilerCleanedUpAfterInFlightTransactionDeallocated() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            XCTAssertFalse(sut.isFinished)
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testFinish_IdleTimeout_ExceedsMaxDuration_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTimeout_ExceedsMaxDuration() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testIdleTimeout_NoChildren_TransactionNotCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTimeout_NoChildren() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let span = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            fixture.dispatchQueueWrapper.invokeLastDispatchAfter()
            XCTAssert(span.isFinished)
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testIdleTransaction_CreatingDispatchBlockFails_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTransaction_CreatingDispatchBlockFails() throws {
        fixture.dispatchQueueWrapper.createDispatchBlockReturnsNULL = true
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let span = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            span.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    /// based on ``SentryTracerTests.testFinish_WaitForAllChildren_StartTimeModified_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_WaitForAllChildren_StartTimeModified() throws {
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        fixture.currentDateProvider.advance(by: 1)
        func performTransaction() throws {
            let sut = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
            XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 499)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
}

private extension SentryProfilerSwiftTests {
    func getLatestProfileData() throws -> Data {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEventWithScopeInvocations.last)

        XCTAssertEqual(1, envelope.additionalEnvelopeItems.count)
        let profileItem = try XCTUnwrap(envelope.additionalEnvelopeItems.first)

        XCTAssertEqual("profile", profileItem.header.type)
        return profileItem.data
    }

    func getLatestTransaction() throws -> Transaction {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEventWithScopeInvocations.last)
        return try XCTUnwrap(envelope.event as? Transaction)
    }

    func addMockSamples(threadMetadata: ThreadMetadata = ThreadMetadata(id: 1, priority: 2, name: "test-thread"), queueMetadata: QueueMetadata = QueueMetadata(address: 3, label: "test-queue"), addresses: [NSNumber] = [0x3, 0x4, 0x5]) {
        let state = SentryProfiler.getCurrent()._state
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, queueAddress: queueMetadata.address, queueLabel: queueMetadata.label, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, queueAddress: queueMetadata.address, queueLabel: queueMetadata.label, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, queueAddress: queueMetadata.address, queueLabel: queueMetadata.label, addresses: addresses)
    }

    struct UIKitParameters {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var launchType: SentryAppStartType
        var prewarmed: Bool
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }

    func performTest(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeOut: Bool = false, uikitParameters: UIKitParameters? = nil) throws {
        var testingAppLaunchSpans = false

            #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        if let uikitParameters = uikitParameters {
            testingAppLaunchSpans = true
            let appStartMeasurement = fixture.getAppStartMeasurement(type: uikitParameters.launchType, preWarmed: uikitParameters.prewarmed)
            SentrySDK.setAppStartMeasurement(appStartMeasurement)
        }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        let span = try fixture.newTransaction(testingAppLaunchSpans: testingAppLaunchSpans)

        addMockSamples()
        fixture.currentDateProvider.advance(by: 31)
        if shouldTimeOut {
            DispatchQueue.main.async {
                self.fixture.timeoutTimerFactory.fire()
            }
        }

        let exp = expectation(description: "finished span")
        DispatchQueue.main.async {
            span.finish()
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)

        try self.assertValidProfileData(transactionEnvironment: transactionEnvironment, shouldTimeout: shouldTimeOut)
    }

    func assertMetricsPayload(metricsBatches: Int = 1) throws {
        let profileData = try self.getLatestProfileData()
        let transaction = try getLatestTransaction()
        let profile = try XCTUnwrap(JSONSerialization.jsonObject(with: profileData) as? [String: Any])
        let measurements = try XCTUnwrap(profile["measurements"] as? [String: Any])

        let expectedUsageReadings = fixture.mockUsageReadingsPerBatch * metricsBatches

        for (i, expectedUsage) in fixture.mockCPUUsages.enumerated() {
            let key = NSString(format: kSentryMetricProfilerSerializationKeyCPUUsageFormat as NSString, i) as String
            try assertMetricValue(measurements: measurements, key: key, numberOfReadings: expectedUsageReadings, expectedValue: expectedUsage, transaction: transaction)
        }

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, numberOfReadings: expectedUsageReadings, expectedValue: fixture.mockMemoryFootprint, transaction: transaction)

#if !os(macOS)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, expectedEntries: fixture.expectedSlowFrames, transaction: transaction)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, expectedEntries: fixture.expectedFrozenFrames, transaction: transaction)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, expectedEntries: fixture.expectedFrameRateChanges, transaction: transaction)
#endif
    }

    func sortedByTimestamps(_ entries: [[String: Any]]) -> [[String: Any]] {
        entries.sorted { a, b in
            UInt64(a["elapsed_since_start_ns"] as! String)! < UInt64(b["elapsed_since_start_ns"] as! String)!
        }
    }

    func printTimestamps(entries: [[String: Any]]) -> [NSString] {
        entries.reduce(into: [NSString](), { partialResult, entry in
            partialResult.append(entry["elapsed_since_start_ns"] as! NSString)
        })
    }

    func assertMetricEntries(measurements: [String: Any], key: String, expectedEntries: [[String: Any]], transaction: Transaction) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let actualEntries = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        let sortedActualEntries = sortedByTimestamps(actualEntries)
        let sortedExpectedEntries = sortedByTimestamps(expectedEntries)

        guard actualEntries.count == expectedEntries.count else {
            XCTFail("Wrong number of values under \(key). expected: \(printTimestamps(entries: sortedExpectedEntries)); actual: \(printTimestamps(entries: sortedActualEntries)); transaction start time: \(transaction.startSystemTime)")
            return
        }

        for i in 0..<actualEntries.count {
            let actualEntry = sortedActualEntries[i]
            let expectedEntry = sortedExpectedEntries[i]

            let actualTimestamp = try XCTUnwrap(actualEntry["elapsed_since_start_ns"] as? NSString)
            let expectedTimestamp = String(UInt64(try XCTUnwrap(expectedEntry["elapsed_since_start_ns"] as? NSString).longLongValue) - transaction.startSystemTime) as NSString
            XCTAssertEqual(actualTimestamp, expectedTimestamp)
            try assertTimestampOccursWithinTransaction(timestamp: actualTimestamp, transaction: transaction)

            let actualValue = try XCTUnwrap(actualEntry["value"] as? NSNumber)
            let expectedValue = try XCTUnwrap(expectedEntry["value"] as? NSNumber)
            XCTAssertEqual(actualValue, expectedValue)
        }
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, numberOfReadings: Int, expectedValue: T? = nil, transaction: Transaction) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let values = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, numberOfReadings, "Wrong number of values under \(key)")

        if let expectedValue = expectedValue {
            let actualValue = try XCTUnwrap(values[0]["value"] as? T)
            XCTAssertEqual(actualValue, expectedValue, "Wrong value for \(key)")

            let timestamp = try XCTUnwrap(values[0]["elapsed_since_start_ns"] as? NSString)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, transaction: transaction)
        }
    }

    /// Assert that the relative timestamp actually falls within the transaction's duration, so it should be between 0 and the transaction duration. The string that holds an elapsed time actually holds an unsigned long long value (due to us using unsigned 64 bit integers, which are not officially supported by JSON), but there is no Cocoa API to get that back out of a string. So, we'll just convert them to signed 64 bit integers, for which there is an API. This likely won't cause a problem because signed 64 bit ints still support large positive values that are likely to be larger than any amount of nanoseconds of a machine's uptime. We can revisit if this actually fails in practice.
    func assertTimestampOccursWithinTransaction(timestamp: NSString, transaction: Transaction) throws {
        let transactionDuration = Int64(getDurationNs(transaction.startSystemTime, transaction.endSystemTime))
        let timestampNumericValue = timestamp.longLongValue
        XCTAssertGreaterThanOrEqual(timestampNumericValue, 0)
        XCTAssertLessThanOrEqual(timestampNumericValue, transactionDuration)
    }

    struct ThreadMetadata {
        var id: UInt64
        var priority: Int32
        var name: String
    }

    struct QueueMetadata {
        var address: UInt64
        var label: String
    }

    func assertValidProfileData(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeout: Bool = false, expectedAddresses: [NSNumber]? = nil, expectedThreadMetadata: [ThreadMetadata]? = nil, expectedQueueMetadata: [QueueMetadata]? = nil) throws {
        let data = try getLatestProfileData()
        let profile = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(profile["version"])

        let device = try XCTUnwrap(profile["device"] as? [String: Any?])
        XCTAssertNotNil(device)
        XCTAssertEqual("Apple", try XCTUnwrap(device["manufacturer"] as? String))
        XCTAssertEqual(try XCTUnwrap(device["locale"] as? String), (NSLocale.current as NSLocale).localeIdentifier)
        XCTAssertFalse(try XCTUnwrap(device["model"] as? String).isEmpty)
#if targetEnvironment(simulator)
        XCTAssertTrue(try XCTUnwrap(device["is_emulator"] as? Bool))
#else
        XCTAssertFalse(try XCTUnwrap(device["is_emulator"] as? Bool))
#endif

        let os = try XCTUnwrap(profile["os"] as? [String: Any?])
        XCTAssertNotNil(os)
        XCTAssertNotNil(try XCTUnwrap(os["name"] as? String))
        XCTAssertFalse(try XCTUnwrap(os["version"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(os["build_number"] as? String).isEmpty)

        let platform = try XCTUnwrap(profile["platform"] as? String)
        XCTAssertEqual("cocoa", platform)

        XCTAssertEqual(transactionEnvironment, try XCTUnwrap(profile["environment"] as? String))

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let expectedReleaseString = "\(bundleID)@\(version)+\(build)"
        let actualReleaseString = try XCTUnwrap(profile["release"] as? String)
        XCTAssertEqual(actualReleaseString, expectedReleaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: try XCTUnwrap(profile["profile_id"] as? String)))

        let debugMeta = try XCTUnwrap(profile["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
        let firstImage = images[0]
        XCTAssertFalse(try XCTUnwrap(firstImage["code_file"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["debug_id"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["image_addr"] as? String).isEmpty)
        XCTAssertGreaterThan(try XCTUnwrap(firstImage["image_size"] as? Int), 0)
        XCTAssertEqual(try XCTUnwrap(firstImage["type"] as? String), "macho")

        let sampledProfile = try XCTUnwrap(profile["profile"] as? [String: Any])
        let threadMetadata = try XCTUnwrap(sampledProfile["thread_metadata"] as? [String: [String: Any]])
        let queueMetadata = try XCTUnwrap(sampledProfile["queue_metadata"] as? [String: [String: Any]])
        XCTAssertFalse(threadMetadata.isEmpty)
        if let expectedThreadMetadata = expectedThreadMetadata {
            try expectedThreadMetadata.forEach {
                let actualThreadMetadata = try XCTUnwrap(threadMetadata["\($0.id)"])
                let actualThreadPriority = try XCTUnwrap(actualThreadMetadata["priority"] as? Int32)
                XCTAssertEqual(actualThreadPriority, $0.priority)
                let actualThreadName = try XCTUnwrap(actualThreadMetadata["name"] as? String)
                XCTAssertEqual(actualThreadName, $0.name)
            }
        } else {
            XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
        }
        XCTAssertFalse(queueMetadata.isEmpty)
        if let expectedQueueMetadata = expectedQueueMetadata {
            try expectedQueueMetadata.forEach {
                let actualQueueMetadata = try XCTUnwrap(queueMetadata[sentry_formatHexAddressUInt64($0.address)])
                let actualQueueLabel = try XCTUnwrap(actualQueueMetadata["label"] as? String)
                XCTAssertEqual(actualQueueLabel, $0.label)
            }
        } else {
            XCTAssertFalse(try XCTUnwrap(try XCTUnwrap(queueMetadata.first?.value)["label"] as? String).isEmpty)
        }

        let samples = try XCTUnwrap(sampledProfile["samples"] as? [[String: Any]])
        XCTAssertFalse(samples.isEmpty)

        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames[0]["instruction_addr"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames[0]["function"] as? String).isEmpty)

        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        var foundAtLeastOneNonEmptySample = false
        XCTAssertFalse(stacks.isEmpty)
        for stack in stacks {
            guard !stack.isEmpty else { continue }
            foundAtLeastOneNonEmptySample = true
            for frameIdx in stack {
                XCTAssertNotNil(frames[frameIdx])
            }
        }
        XCTAssert(foundAtLeastOneNonEmptySample)

        let latestTransaction = try getLatestTransaction()
        let linkedTransactionInfo = try XCTUnwrap(profile["transaction"] as? [String: Any])

        let linkedTransactionTimestampString = try XCTUnwrap(profile["timestamp"] as? String)
        let latestTransactionTimestampString = (latestTransaction.trace.originalStartTimestamp as NSDate).sentry_toIso8601String()
        XCTAssertEqual(linkedTransactionTimestampString, latestTransactionTimestampString)

        XCTAssertEqual(fixture.transactionName, latestTransaction.transaction)
        XCTAssertEqual(fixture.transactionName, try XCTUnwrap(linkedTransactionInfo["name"] as? String))

        let linkedTransactionId = SentryId(uuidString: try XCTUnwrap(linkedTransactionInfo["id"] as? String))
        XCTAssertEqual(latestTransaction.eventId, linkedTransactionId)
        XCTAssertNotEqual(SentryId.empty, linkedTransactionId)

        let linkedTransactionTraceId = SentryId(uuidString: try XCTUnwrap(linkedTransactionInfo["trace_id"] as? String))
        XCTAssertEqual(latestTransaction.trace.traceId, linkedTransactionTraceId)
        XCTAssertNotEqual(SentryId.empty, linkedTransactionTraceId)

        let activeThreadId = try XCTUnwrap(linkedTransactionInfo["active_thread_id"] as? NSNumber)
        XCTAssertEqual(activeThreadId, latestTransaction.trace.transactionContext.sentry_threadInfo().threadId)

        for sample in samples {
            let timestamp = try XCTUnwrap(sample["elapsed_since_start_ns"] as? NSString)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, transaction: latestTransaction)
            XCTAssertNotNil(sample["thread_id"])
            let stackIDEntry = try XCTUnwrap(sample["stack_id"])
            let stackID = try XCTUnwrap(stackIDEntry as? Int)
            XCTAssertNotNil(stacks[stackID])
        }

        if shouldTimeout {
            XCTAssertEqual(try XCTUnwrap(profile["truncation_reason"] as? String), profilerTruncationReasonName(.timeout))
        }
    }

    func assertProfilesSampler(expectedDecision: SentrySampleDecision, options: (Options) -> Void) throws {
        let fixtureOptions = fixture.options
        fixtureOptions.tracesSampleRate = 1.0
        fixtureOptions.profilesSampleRate = nil
        fixtureOptions.profilesSampler = { _ in
            switch expectedDecision {
            case .undecided, .no:
                return NSNumber(value: 0)
            case .yes:
                return NSNumber(value: 1)
            @unknown default:
                XCTFail("Unexpected value for sample decision")
                return NSNumber(value: 0)
            }
        }
        options(fixtureOptions)

        let hub = fixture.hub
        Dynamic(hub).tracesSampler.random = TestRandom(value: 1.0)

        let span = try fixture.newTransaction()
        addMockSamples()
        fixture.currentDateProvider.advance(by: 5)
        span.finish()

        let client = try XCTUnwrap(self.fixture.client)

        switch expectedDecision {
        case .undecided, .no:
            let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first)
            XCTAssertEqual(0, event.additionalEnvelopeItems.count)
        case .yes:
            let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first)
            XCTAssertEqual(1, event.additionalEnvelopeItems.count)
        @unknown default:
            XCTFail("Unexpected value for sample decision")
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

let system = SentrySystemWrapper()

extension SentryProfilerSwiftTests {
    func work() {
        var results = [Double]()
        for _ in 0..<1_000 {
            let a = UInt64(arc4random())
            let b = UInt64(arc4random())
            let c = a + b
            let d = a > b ? a - b : b - a
            let e = c / d
            let f = d / c
            let g = a % b
            let h = b % a
            let i = e * g
            let j = f * h
            let k = e * h
            let l = f * g
            let m = sqrt(Double(a))
            let n = sqrt(Double(b))
            let o = m * n
            let p = atan2(m, n)
            results.append(Double(i + j + k + l) + o + p)
        }
        let _ = results.average
    }

    func testQueuesAndThreads() {
//        let privateUtilityQueue = DispatchQueue(label: "private utility", qos: .utility)
        let privateBackgroundQueue = DispatchQueue(label: "private bg", qos: .background)

        func scheduleBlocks(_ queue: DispatchQueue, _ number: Int, _ queueName: String, _ exp: XCTestExpectation, slow: Bool = false, work: Bool = true) {
            for _ in 0..<number {
                queue.async {
                    if slow { sleep(5) }
                    if work { self.work() }
//                    print("queue: \(queueName); thread: \(String(reflecting: Thread.current));\ncpu usage: \(String(reflecting: try! system.cpuUsagePerCore()));\ncpu info:\n\(String(reflecting: try! system.cpuInfo()))")
                    exp.fulfill()
                }
            }
        }

        let qosClasses = 2
        let workUnits = 1_000
        let expectedFulfillmentCount = qosClasses * workUnits

        let multithreaded = benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = expectedFulfillmentCount

            [
                "main": DispatchQueue.main,
//                "global background": DispatchQueue.global(qos: .background),
//                "global user initiated": DispatchQueue.global(qos: .userInitiated),
//                "global utility": DispatchQueue.global(qos: .utility),
//                "private serial utility": privateUtilityQueue,
                "private serial background": privateBackgroundQueue
            ].forEach {
                scheduleBlocks($0.value, workUnits, $0.key, exp)
            }

            self.waitForExpectations(timeout: 10)
        }

        let mainThreadOnly = benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = expectedFulfillmentCount
            scheduleBlocks(DispatchQueue.main, expectedFulfillmentCount, "main", exp)
            self.waitForExpectations(timeout: 10)
        }

//        print("multithreaded: \(multithreaded)")
//        print("mainThreadOnly: \(mainThreadOnly)")
        print("multithreaded - main thread only: \(multithreaded.diff(other: mainThreadOnly))")
    }

    func testFail() {
        XCTFail()
    }
}

typealias ThreadUsage = (time: UInt64, usagePercent: Double)
struct BenchmarkStats: CustomStringConvertible {
    var averageCPUPowerUsage_nJ: Double
    var averageGPUPowerUsage_nJ: Double
    var averageProcessorSwitches: Double
    var averageWallClockTime_ns: Int64
    var averageContextSwitches: Double
//    var averageCPUUsagesPerThread: [UInt64: ThreadUsage]

    var description: String {
        String([
            "average total CPU power usage: \(averageCPUPowerUsage_nJ) nJ",
            "average total GPU power usage: \(averageGPUPowerUsage_nJ) nJ",
            "average processor switches: \(averageProcessorSwitches)",
            "average wall clock time: \(averageWallClockTime_ns) ns",
            "average context switches: \(averageContextSwitches)"
        ].joined(separator: "\n"))
    }

    // self - other
    func diff(other: BenchmarkStats) -> BenchmarkStats {
        return BenchmarkStats(
            averageCPUPowerUsage_nJ: averageCPUPowerUsage_nJ - other.averageCPUPowerUsage_nJ,
            averageGPUPowerUsage_nJ: averageGPUPowerUsage_nJ - other.averageGPUPowerUsage_nJ,
            averageProcessorSwitches: averageProcessorSwitches - other.averageProcessorSwitches,
            averageWallClockTime_ns: averageWallClockTime_ns - other.averageWallClockTime_ns,
            averageContextSwitches: averageContextSwitches - other.averageContextSwitches
        )
    }
}

func benchmark(block: @escaping () -> Void) -> BenchmarkStats {
    var cpuPowerUsages = [UInt64]()
    var gpuPowerUsages = [UInt64]()
    var pswitches = [UInt64]()
    var contextSwitches = [UInt64]()
//    var cpuTimePerThread = [SentryCPUUsagePerThread]()
    var cpuTicks = [UInt64]()
    let averageWallClockTime = dispatch_benchmark(10) {
        let startingPowerUsage = try! system.powerUsage()
        let startingContextSwitches = try! system.numContextSwitches()
//        let startingCPUUsagePerThread = try! system.cpuUsagePerThread()
        let startingCPUTicks = try! system.cpuTicks()

        block()

        let endingPowerUsage = try! system.powerUsage()
        let totalCPUPowerUsed = endingPowerUsage.totalCPU() - startingPowerUsage.totalCPU()
        cpuPowerUsages.append(totalCPUPowerUsed)

        let totalGPUPowerUsed = endingPowerUsage.totalGPU() - startingPowerUsage.totalGPU()
        gpuPowerUsages.append(totalGPUPowerUsed)

        let totalPswitches = endingPowerUsage.info.task_pset_switches - startingPowerUsage.info.task_pset_switches
        pswitches.append(totalPswitches)

        let endingContextSwitches = try! system.numContextSwitches()
        let totalContextSwitches = endingContextSwitches.uint64Value - startingContextSwitches.uint64Value
        contextSwitches.append(totalContextSwitches)

//        let endingCPUUsagePerThread = try! system.cpuUsagePerThread()
//        let totalCPUUsagePerThread = SentryCPUUsagePerThread()
//        endingCPUUsagePerThread.usages.allKeys.forEach { key in
//            guard let start = startingCPUUsagePerThread.usages[key] as? SentryThreadCPUUsage else { return }
//            guard let end = endingCPUUsagePerThread.usages[key] as? SentryThreadCPUUsage else { return }
//            let system = end.data.system_time.seconds - start.data.system_time.seconds + end.data.system_time.microseconds - start.data.system_time.microseconds
//            let user = end.data.user_time.seconds - start.data.user_time.seconds + end.data.user_time.microseconds - start.data.user_time.microseconds
//            let usage = end.data.cpu_usage - start.data.cpu_usage
//            totalCPUUsagePerThread.usages[key] = (system, user, usage)
//        }
//        cpuTimePerThread.append(totalCPUUsagePerThread)

        let endingCPUTicks = try! system.cpuTicks()
        let totalCPUTicks = endingCPUTicks.total() - startingCPUTicks.total()
        cpuTicks.append(totalCPUTicks)
    }

//    var threadCounts = [UInt64: UInt64]()
//    let totalUsagePerThread = cpuTimePerThread.reduce(into: [UInt64: ThreadUsage]) { partialResult, next in
//
//    }

    return BenchmarkStats(averageCPUPowerUsage_nJ: cpuPowerUsages.average, averageGPUPowerUsage_nJ: gpuPowerUsages.average, averageProcessorSwitches: pswitches.average, averageWallClockTime_ns: Int64(averageWallClockTime), averageContextSwitches: contextSwitches.average)
}

extension Array where Element == UInt64 {
    var average: Double {
        Double(reduce(0, +)) / Double(count)
    }
}

extension Array where Element == Double {
    var average: Double {
        reduce(0, +) / Double(count)
    }
}
