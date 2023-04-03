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

        let currentDateProvider = TestCurrentDateProvider()

#if !os(macOS)
        lazy var displayLinkWrapper = TestDisplayLinkWrapper()
        lazy var framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
#endif

        /// Advance the mock date provider, start a new transaction and return its handle.
        func newTransaction(testingAppLaunchSpans: Bool = false) throws -> SentryTracer {
            currentDateProvider.advanceBy(nanoseconds: 2)
            if testingAppLaunchSpans {
                return try XCTUnwrap(hub.startTransaction(name: transactionName, operation: SentrySpanOperationUILoad) as? SentryTracer)
            }
            return try XCTUnwrap(hub.startTransaction(name: transactionName, operation: transactionOperation) as? SentryTracer)
        }

        // mocking

        let mockCPUUsages = [12.4, 63.5, 1.4, 4.6]
        let mockMemoryFootprint: SentryRAMBytes = 123_455
        let mockUsageReadingsPerBatch = 2

#if !os(macOS)
        // SentryFramesTracker starts assuming a frame rate of 60 Hz and will only log an update if it changes, so the first value here needs to be different for it to register.
        let mockFrameRateChangesPerBatch: [FrameRate] = [.high, .low, .high, .low]
#endif

        func prepareMetricsMocks() {
            SentryProfiler.useSystemWrapper(systemWrapper)
            SentryProfiler.useProcessInfoWrapper(processInfoWrapper)
            SentryProfiler.useTimerWrapper(timerWrapper)

            systemWrapper.overrides.cpuUsagePerCore = mockCPUUsages.map { NSNumber(value: $0) }
            processInfoWrapper.overrides.processorCount = UInt(mockCPUUsages.count)
            systemWrapper.overrides.memoryFootprintBytes = mockMemoryFootprint

#if !os(macOS)
            SentryProfiler.useFramesTracker(framesTracker)
            framesTracker.start()
            displayLinkWrapper.call()
#endif
        }

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
                self.timerWrapper.fire()
            }

    #if !os(macOS)
            var shouldRecordFrameRateExpectation = false
            var _previousSystemTime = currentDateProvider.systemTime()

            func changeFrameRate(_ new: FrameRate) {
                displayLinkWrapper.changeFrameRate(new)
                shouldRecordFrameRateExpectation = true
            }

            func renderGPUFrame(_ type: GPUFrame) {
                if shouldRecordFrameRateExpectation {
                    shouldRecordFrameRateExpectation = false
                    print("will expect frame rate \(displayLinkWrapper.currentFrameRate.rawValue) at \(_previousSystemTime)")
                    expectedFrameRateChanges.append([
                        "elapsed_since_start_ns": String(_previousSystemTime),
                        "value": NSNumber(value: displayLinkWrapper.currentFrameRate.rawValue)
                    ])
                }

                switch type {
                case .normal:
                    currentDateProvider.advanceBy(nanoseconds: 1)
                    let currentSystemTime: UInt64 = currentDateProvider.systemTime()
                    print("expect normal frame to start at \(_previousSystemTime) and end at \(currentSystemTime)")
                    _previousSystemTime = currentSystemTime

                    displayLinkWrapper.normalFrame()
                case .slow:
                    let duration: UInt64 = 3
                    currentDateProvider.advanceBy(nanoseconds: duration)
                    let currentSystemTime = currentDateProvider.systemTime()
                    print("will expect \(String(describing: type)) frame starting at \(_previousSystemTime) and ending at \(currentSystemTime)")
                    expectedSlowFrames.append([
                        "elapsed_since_start_ns": String(_previousSystemTime),
                        "value": duration
                    ])
                    _previousSystemTime = currentSystemTime

                    displayLinkWrapper.middlingSlowFrame()
                case .frozen:
                    let duration: UInt64 = 10
                    currentDateProvider.advanceBy(nanoseconds: duration)
                    let currentSystemTime = currentDateProvider.systemTime()
                    print("will expect \(String(describing: type)) frame starting at \(_previousSystemTime) and ending at \(currentSystemTime)")
                    expectedFrozenFrames.append([
                        "elapsed_since_start_ns": String(_previousSystemTime),
                        "value": duration
                    ])
                    _previousSystemTime = currentSystemTime

                    displayLinkWrapper.fastestFrozenFrame()
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
            renderGPUFrame(.slow)
            renderGPUFrame(.normal)
            renderGPUFrame(.frozen)
    #endif

            // mock errors gathering cpu usage and memory footprint and fire a callback for them to ensure they don't add more information to the payload
            systemWrapper.overrides.cpuUsageError = NSError(domain: "test-error", code: 0)
            systemWrapper.overrides.memoryFootprintError = NSError(domain: "test-error", code: 1)
            timerWrapper.fire()
        }

        // app start simulation

        lazy var appStart = currentDateProvider.date()
        var appStartDuration = 0.5
        lazy var appStartEnd = appStart.addingTimeInterval(appStartDuration)

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
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryLog.configure(true, diagnosticLevel: .debug)
        CurrentDate.setCurrentDateProvider(fixture.currentDateProvider)
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        fixture.prepareMetricsMocks()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testMetricProfiler() throws {
        // start span
        let span = try fixture.newTransaction()
        forceProfilerSample()

        try fixture.gatherMockedMetrics(span: span)

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
        let numberOfTransactions = 10
        var spans = [Span]()

        for _ in 0 ..< numberOfTransactions {
            spans.append(try fixture.newTransaction())
        }

        forceProfilerSample()

        for (i, span) in spans.enumerated() {
            try fixture.gatherMockedMetrics(span: span)
            span.finish()

            try self.assertValidProfileData()
            try self.assertMetricsPayload(metricsBatches: i + 1)
        }

        // do everything again to make sure that stopping and starting the profiler over again works
        spans.removeAll()
        fixture.currentDateProvider.reset()
#if !os(macOS)
        fixture.resetGPUExpectations()
        fixture.framesTracker.resetFrames()
#endif
        fixture.prepareMetricsMocks()

        for _ in 0 ..< numberOfTransactions {
            spans.append(try fixture.newTransaction())
        }

        forceProfilerSample()

#if !os(macOS)
        fixture.displayLinkWrapper.call()
#endif
        for (i, span) in spans.enumerated() {
            try fixture.gatherMockedMetrics(span: span)
            span.finish()

            try self.assertValidProfileData()
            try self.assertMetricsPayload(metricsBatches: i + 1)
        }
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
        let originalTimeoutInterval = kSentryProfilerTimeoutInterval
        kSentryProfilerTimeoutInterval = 1

        let spanA = try fixture.newTransaction()

        forceProfilerSample()

        // cause spanA profiler to time out
        let exp = expectation(description: "spanA times out")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3)

        let spanB = try fixture.newTransaction()

        forceProfilerSample()

        spanB.finish()
        try self.assertValidProfileData()

        spanA.finish()
        try self.assertValidProfileData()

        kSentryProfilerTimeoutInterval = originalTimeoutInterval
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

    func testProfileWithTransactionContainingStartupSpansForColdStart() throws {
        try performTest(launchType: .cold, prewarmed: false)
    }

    func testProfileWithTransactionContainingStartupSpansForWarmStart() throws {
        try performTest(launchType: .warm, prewarmed: false)
    }

    func testProfileWithTransactionContainingStartupSpansForPrewarmedStart() throws {
        try performTest(launchType: .cold, prewarmed: true)
    }

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

    func performTest(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeOut: Bool = false, launchType: SentryAppStartType? = nil, prewarmed: Bool = false) throws {
        var testingAppLaunchSpans = false
        if let launchType = launchType {
            testingAppLaunchSpans = true
            let appStartMeasurement = fixture.getAppStartMeasurement(type: launchType, preWarmed: prewarmed)
            SentrySDK.setAppStartMeasurement(appStartMeasurement)
        }

        let originalTimeoutInterval = kSentryProfilerTimeoutInterval
        if shouldTimeOut {
            kSentryProfilerTimeoutInterval = 1
        }
        let span = try fixture.newTransaction(testingAppLaunchSpans: testingAppLaunchSpans)

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

    func printTimestamps(entries: [[String: Any]]) {
        print(entries.reduce(into: [NSString](), { partialResult, entry in
            partialResult.append(entry["elapsed_since_start_ns"] as! NSString)
        }))
    }

    func assertMetricEntries(measurements: [String: Any], key: String, expectedEntries: [[String: Any]], transaction: Transaction) throws {
        guard let metricContainer = measurements[key] as? [String: Any] else {
            throw TestError.noMetricsReported
        }
        guard let actualEntries = metricContainer["values"] as? [[String: Any]] else {
            throw TestError.malformedMetricValueEntry
        }
        let sortedActualEntries = sortedByTimestamps(actualEntries)
        let sortedExpectedEntries = sortedByTimestamps(expectedEntries)

        let expectedAmountOfReadings = actualEntries.count == expectedEntries.count
        XCTAssert(expectedAmountOfReadings, "Wrong number of values under \(key). expected: \(sortedExpectedEntries); actual: \(sortedActualEntries); transaction start time: \(transaction.startSystemTime)")

        guard expectedAmountOfReadings else {
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
                fatalError("Unexpected value for sample decision")
            }
        }
        options(fixtureOptions)

        let hub = fixture.hub
        Dynamic(hub).tracesSampler.random = TestRandom(value: 1.0)

        let span = try fixture.newTransaction()
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
