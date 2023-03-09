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
        lazy var timerWrapper = TestSentryNSTimerWrapper()

#if !os(macOS)
        lazy var displayLinkWrapper = TestDisplayLinkWrapper()
        lazy var framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
#endif

        func newTransaction() -> Span {
            hub.startTransaction(name: transactionName, operation: transactionOperation)
        }

        // mocking

        let mockCPUUsages = [12.4, 63.5, 1.4, 4.6]
        let mockMemoryFootprint: SentryRAMBytes = 123_455
        let mockUsageReadingsPerBatch = 2
        let mockSlowFramesPerBatch = 2
        let mockFrozenFramesPerBatch = 1

        // SentryFramesTracker starts assuming a frame rate of 60 Hz and will only log an update if it changes, so the first value here needs to be different for it to register.
        let mockFrameRateChangesPerBatch: [Double] = [120.0, 60.0, 120.0, 60.0]

        func mockMetricsSubsystems() {
            SentryProfiler.useSystemWrapper(systemWrapper)
            SentryProfiler.useProcessInfoWrapper(processInfoWrapper)
            SentryProfiler.useTimerWrapper(timerWrapper)
    #if !os(macOS)
            SentryProfiler.useFramesTracker(framesTracker)
    #endif
        }

        func prepareMetricsMocks() {
            systemWrapper.overrides.cpuUsagePerCore = mockCPUUsages.map { NSNumber(value: $0) }
            processInfoWrapper.overrides.processorCount = UInt(mockCPUUsages.count)

            systemWrapper.overrides.memoryFootprintBytes = mockMemoryFootprint
        }

        func gatherMockedMetrics() {
            // clear out any errors that might've been set in previous calls
            systemWrapper.overrides.cpuUsageError = nil
            systemWrapper.overrides.memoryFootprintError = nil

            // gather mock cpu usages and memory footprints
            for _ in 0..<mockUsageReadingsPerBatch {
                self.timerWrapper.fire()
            }

    #if !os(macOS)
            // gather mock GPU frame render timestamps
            displayLinkWrapper.call() // call once directly to capture previous frame timestamp for comparison with later ones

            var slowFrames = 0
            var frozenFrames = 0
            var frameRates = 0
            for _ in 0..<max(mockSlowFramesPerBatch, mockFrozenFramesPerBatch, mockFrameRateChangesPerBatch.count) {
                displayLinkWrapper.normalFrame()
                if slowFrames < mockSlowFramesPerBatch {
                    displayLinkWrapper.slowFrame()
                    slowFrames += 1
                }
                displayLinkWrapper.normalFrame()
                if frozenFrames < mockFrozenFramesPerBatch {
                    displayLinkWrapper.frozenFrame()
                    frozenFrames += 1
                }
                displayLinkWrapper.normalFrame()
                if frameRates < mockFrameRateChangesPerBatch.count {
                    displayLinkWrapper.changeFrameRate(mockFrameRateChangesPerBatch[frameRates])
                    frameRates += 1
                }
                displayLinkWrapper.normalFrame()
            }

    #endif

            // mock errors gathering cpu usage and memory footprint and fire a callback for them to ensure they don't add more information to the payload
            systemWrapper.overrides.cpuUsageError = NSError(domain: "test-error", code: 0)
            systemWrapper.overrides.memoryFootprintError = NSError(domain: "test-error", code: 1)
            timerWrapper.fire()
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryTracer.resetAppStartMeasurementRead()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
        SentryTracer.resetAppStartMeasurementRead()
#if !os(macOS)
        SentryFramesTracker.sharedInstance().resetFrames()
        SentryFramesTracker.sharedInstance().stop()
#endif
    }

    func testMetricProfiler() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0

        fixture.mockMetricsSubsystems()

        fixture.mockMetricsSubsystems()
        fixture.prepareMetricsMocks()

        // start span
        let span = fixture.newTransaction()
        forceProfilerSample()

#if !os(macOS)
        fixture.framesTracker.start()
#endif
        fixture.gatherMockedMetrics()
#if !os(macOS)
        fixture.framesTracker.stop()
#endif

        // finish profile
        let exp = expectation(description: "Receives profile payload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            span.finish()
            do {
                try self.assertMetricsPayload()
                exp.fulfill()
            } catch {
                XCTFail("Encountered error: \(error)")
            }
        }
        waitForExpectations(timeout: 3)
    }

    func testConcurrentProfilingTransactions() throws {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0
        fixture.mockMetricsSubsystems()
        fixture.prepareMetricsMocks()

        let numberOfTransactions = 10
        var spans = [Span]()

        for _ in 0 ..< numberOfTransactions {
            spans.append(fixture.newTransaction())
        }

        forceProfilerSample()

#if !os(macOS)
        fixture.framesTracker.start()
#endif
        for (i, span) in spans.enumerated() {
            fixture.gatherMockedMetrics()

            span.finish()

            try self.assertValidProfileData()
            try self.assertMetricsPayload(metricsBatches: i + 1)
        }

        // do everything again to make sure that stopping and starting the profiler over again works
        spans.removeAll()

        for _ in 0 ..< numberOfTransactions {
            spans.append(fixture.newTransaction())
        }

        forceProfilerSample()

        for (i, span) in spans.enumerated() {
            fixture.gatherMockedMetrics()

            span.finish()

            try self.assertValidProfileData()
            try self.assertMetricsPayload(metricsBatches: i + 1)
        }
#if !os(macOS)
        fixture.framesTracker.stop()
#endif
    }

    /// Test a situation where a long-running span starts the profiler, which winds up timing out, and then another span starts that begins a new profile, then finishes, and then the long-running span finishes; both profiles should be separately captured in envelopes.
    /// ```
    ///    time                0s                         1s     2s     2.5s     3s  (these times are adjusted to the 1s profile timeout for testing only)
    ///    transaction A       |---------------------------------------------------|
    ///    profiler A          |---------------------------x  <- timeout
    ///    transaction B                                           |-------|
    ///    profiler B                                              |-------|  <- normal finish
    ///   ```
    func testConcurrentSpansWithTimeout() throws {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0
        let originalTimeoutInterval = kSentryProfilerTimeoutInterval
        kSentryProfilerTimeoutInterval = 1

        let spanA = fixture.newTransaction()

        forceProfilerSample()

        // cause spanA profiler to time out
        let exp = expectation(description: "spanA times out")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3)

        let spanB = fixture.newTransaction()

        forceProfilerSample()

        spanB.finish()
        try self.assertValidProfileData()

        spanA.finish()
        try self.assertValidProfileData()

        kSentryProfilerTimeoutInterval = originalTimeoutInterval
    }

    func testProfileTimeoutTimer() throws {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        try performTest(shouldTimeOut: true)
    }

    func testStartTransaction_ProfilingDataIsValid() throws {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        try performTest()
    }

    func testProfilingDataContainsEnvironmentSetFromOptions() throws {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        try performTest(transactionEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScope() throws {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performTest(transactionEnvironment: expectedEnvironment)
    }

    func testStartTransaction_NotSamplingProfileUsingEnableProfiling() {
        assertProfilesSampler(expectedDecision: .no) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = false
        }
    }

    func testStartTransaction_SamplingProfileUsingEnableProfiling() {
        assertProfilesSampler(expectedDecision: .yes) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = true
        }
    }

    func testStartTransaction_NotSamplingProfileUsingSampleRate() {
        assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = 0.49
        }
    }

    func testStartTransaction_SamplingProfileUsingSampleRate() {
        assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampleRate = 0.5
        }
    }

    func testStartTransaction_SamplingProfileUsingProfilesSampler() {
        assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampler = { _ in return 0.51 }
        }
    }

    func testStartTransaction_WhenProfilesSampleRateAndProfilesSamplerNil() {
        assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = nil
            options.profilesSampler = { _ in return nil }
        }
    }

    func testStartTransaction_WhenProfilesSamplerOutOfRange_TooBig() {
        assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return 1.01 }
        }
    }

    func testStartTransaction_WhenProfilesSamplersOutOfRange_TooSmall() {
        assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return -0.01 }
        }
    }
}

private extension SentryProfilerSwiftTests {
    enum TestError: Error {
        case unexpectedProfileDeserializationType
        case unexpectedMeasurementsDeserializationType
        case noEnvelopeCaptured
        case noProfileEnvelopeItem
        case malformedMetricValueEntry
        case noMetricsReported
        case noMetricValuesFound
    }

    func getLatestProfileData() throws -> Data {
        guard let envelope = try XCTUnwrap(self.fixture.client).captureEventWithScopeInvocations.last else {
            throw(TestError.noEnvelopeCaptured)
        }

        XCTAssertEqual(1, envelope.additionalEnvelopeItems.count)
        guard let profileItem = envelope.additionalEnvelopeItems.first else {
            throw(TestError.noProfileEnvelopeItem)
        }

        XCTAssertEqual("profile", profileItem.header.type)
        return profileItem.data
    }

    func getLatestTransaction() throws -> Transaction {
        guard let envelope = try XCTUnwrap(self.fixture.client).captureEventWithScopeInvocations.last else {
            throw(TestError.noEnvelopeCaptured)
        }

        return try XCTUnwrap(envelope.event as? Transaction)
    }

    /// Keep a thread busy over a long enough period of time (long enough for 3 samples) for the sampler to pick it up.
    func forceProfilerSample() {
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }
    }

    func performTest(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeOut: Bool = false) throws {
        let originalTimeoutInterval = kSentryProfilerTimeoutInterval
        if shouldTimeOut {
            kSentryProfilerTimeoutInterval = 1
        }
        let span = fixture.newTransaction()

        forceProfilerSample()

        let exp = expectation(description: "profiler should finish")
        if shouldTimeOut {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                span.finish()
                exp.fulfill()
            }
        } else {
            span.finish()
            exp.fulfill()
        }

        waitForExpectations(timeout: 10)

        try self.assertValidProfileData(transactionEnvironment: transactionEnvironment, shouldTimeout: shouldTimeOut)

        if shouldTimeOut {
            kSentryProfilerTimeoutInterval = originalTimeoutInterval
        }
    }

    func assertMetricsPayload(metricsBatches: Int = 1) throws {
        let profileData = try self.getLatestProfileData()
        let transaction = try getLatestTransaction()
        guard let profile = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] else {
            throw TestError.unexpectedProfileDeserializationType
        }
        guard let measurements = profile["measurements"] as? [String: Any] else {
            throw TestError.unexpectedMeasurementsDeserializationType
        }

        let expectedUsageReadings = fixture.mockUsageReadingsPerBatch * metricsBatches

        for (i, expectedUsage) in fixture.mockCPUUsages.enumerated() {
            let key = NSString(format: kSentryMetricProfilerSerializationKeyCPUUsageFormat as NSString, i) as String
            try assertMetricValue(measurements: measurements, key: key, numberOfReadings: expectedUsageReadings, expectedValue: expectedUsage, transaction: transaction)
        }

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, numberOfReadings: expectedUsageReadings, expectedValue: fixture.mockMemoryFootprint, transaction: transaction)

#if !os(macOS)
        // can't elide the value argument, because assertMetricValue is generic and the parameter type won't be able to be inferred, so we provide a dummy variable/value
        let dummyValue: UInt64? = nil
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, numberOfReadings: fixture.mockSlowFramesPerBatch * metricsBatches, expectedValue: dummyValue, transaction: transaction)
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, numberOfReadings: fixture.mockFrozenFramesPerBatch * metricsBatches, expectedValue: dummyValue, transaction: transaction)

        // need to add 1 frame rate reading because there is always an initial one for the frame rate when the frame tracker starts
        let expectedFrameRateReadings = 1 + fixture.mockFrameRateChangesPerBatch.count * metricsBatches
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, numberOfReadings: expectedFrameRateReadings, expectedValue: dummyValue, transaction: transaction)
#endif
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, numberOfReadings: Int, expectedValue: T?, transaction: Transaction) throws {
        guard let metricContainer = measurements[key] as? [String: Any] else {
            throw TestError.noMetricsReported
        }
        guard let values = metricContainer["values"] as? [[String: Any]] else {
            throw TestError.malformedMetricValueEntry
        }
        XCTAssertEqual(values.count, numberOfReadings, "Wrong number of values under \(key)")

        if let expectedValue = expectedValue {
            guard let actualValue = values[0]["value"] as? T else {
                throw TestError.noMetricValuesFound
            }
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

    func assertValidProfileData(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeout: Bool = false) throws {
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
        let queueMetadata = try XCTUnwrap(sampledProfile["queue_metadata"] as? [String: Any])
        XCTAssertFalse(threadMetadata.isEmpty)
        XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
        XCTAssertFalse(queueMetadata.isEmpty)
        XCTAssertFalse(try XCTUnwrap(try XCTUnwrap(queueMetadata.first?.value as? [String: Any])["label"] as? String).isEmpty)

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
        let latestTransactionTimestampString = (latestTransaction.startTimestamp as NSDate?)?.sentry_toIso8601String()
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

    func assertProfilesSampler(expectedDecision: SentrySampleDecision, options: (Options) -> Void) {
        let fixtureOptions = fixture.options
        fixtureOptions.tracesSampleRate = 1.0
        fixtureOptions.profilesSampler = { _ in
            switch expectedDecision {
            case .undecided, .no:
                return NSNumber(value: 0)
            case .yes:
                return NSNumber(value: 1)
            @unknown default:
                fatalError("Unexpected value for sample decision")
            }
        }
        options(fixtureOptions)

        let hub = fixture.hub
        Dynamic(hub).tracesSampler.random = TestRandom(value: 1.0)

        let span = fixture.newTransaction()
        let exp = expectation(description: "Span finishes")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            guard let client = self.fixture.client else {
                XCTFail("Expected a valid test client to exist")
                return
            }

            switch expectedDecision {
            case .undecided, .no:
                guard let event = client.captureEventWithScopeInvocations.first else {
                    XCTFail("Expected to capture at least 1 event, but without a profile")
                    return
                }
                XCTAssertEqual(0, event.additionalEnvelopeItems.count)
            case .yes:
                guard let event = client.captureEventWithScopeInvocations.first else {
                    XCTFail("Expected to capture at least 1 event with a profile")
                    return
                }
                XCTAssertEqual(1, event.additionalEnvelopeItems.count)
            @unknown default:
                fatalError("Unexpected value for sample decision")
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 3)
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
