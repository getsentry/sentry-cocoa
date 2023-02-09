import Sentry
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
        lazy var client: TestClient = TestClient(options: options)!
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
        SentryProfiler.useSystemWrapper(fixture.systemWrapper)
        SentryProfiler.useProcessInfoWrapper(fixture.processInfoWrapper)
        SentryProfiler.useTimerWrapper(fixture.timerWrapper)
#if !os(macOS)
        SentryProfiler.useFramesTracker(fixture.framesTracker)
#endif

        // mock cpu usage
        let cpuUsages = [12.4, 63.5, 1.4, 4.6]
        fixture.systemWrapper.overrides.cpuUsagePerCore = cpuUsages.map { NSNumber(value: $0) }
        fixture.processInfoWrapper.overrides.processorCount = UInt(cpuUsages.count)

        // mock memory footprint
        let memoryFootprint: SentryRAMBytes = 123_455
        fixture.systemWrapper.overrides.memoryFootprintBytes = memoryFootprint

        // TODO: gather some SentryFramesTracker events to make sure they don't make it into the profile payload after slicing metrics

        let span = fixture.newTransaction()
        forceProfilerSample()

        // gather mock cpu usages and memory footprints
        for _ in 0..<2 {
            self.fixture.timerWrapper.fire()
        }

#if !os(macOS)
        // gather mock GPU frame render timestamps
        fixture.framesTracker.start()
        fixture.displayLinkWrapper.call() // call once directly to capture previous frame timestamp for comparison with later ones
        fixture.displayLinkWrapper.slowFrame()
        fixture.displayLinkWrapper.changeFrameRate(120.0)
        fixture.displayLinkWrapper.normalFrame()
        fixture.displayLinkWrapper.almostFrozenFrame()
        fixture.displayLinkWrapper.changeFrameRate(60.0)
        fixture.displayLinkWrapper.normalFrame()
        fixture.displayLinkWrapper.frozenFrame()
        fixture.framesTracker.stop()
#endif

        // mock errors gathering cpu usage and memory footprint to ensure they don't add more information to the payload
        fixture.systemWrapper.overrides.cpuUsageError = NSError(domain: "test-error", code: 0)
        fixture.systemWrapper.overrides.memoryFootprintError = NSError(domain: "test-error", code: 1)
        self.fixture.timerWrapper.fire()

        // finish profile
        let exp = expectation(description: "Receives profile payload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            span.finish()

            // TODO: gather more metrics to make sure they don't make it into the profile payload after slicing metrics

            do {
                try self.assertMetricsPayload(expectedCPUUsages: cpuUsages, usageReadings: 2, expectedMemoryFootprint: memoryFootprint, expectedSlowFrameCount: 2, expectedFrozenFrameCount: 1, expectedFrameRateCount: 3)
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

        let numberOfTransactions = 10
        var spans = [Span]()
        for _ in 0 ..< numberOfTransactions {
            spans.append(fixture.newTransaction())
        }

        forceProfilerSample()

        try spans.forEach {
            $0.finish()

            let profileData = try getProfileData()
            self.assertValidProfileData(data: profileData)
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

        // TODO: newTransaction, getProfileData and assertValidProfileData need additional arguments so we can know the correct transaction info is injected into the right profile payloads and profiles are then attached to the correct transactions.

        spanB.finish()
        var profileData = try getProfileData()
        self.assertValidProfileData(data: profileData)

        spanA.finish()
        profileData = try getProfileData()
        self.assertValidProfileData(data: profileData)

        kSentryProfilerTimeoutInterval = originalTimeoutInterval
    }

    func testSlicingProfileSamplesAndMetrics() {
        // TODO: implement
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

    func getProfileData() throws -> Data {
        guard let envelope = self.fixture.client.captureEventWithScopeInvocations.last else {
            throw(TestError.noEnvelopeCaptured)
        }

        XCTAssertEqual(1, envelope.additionalEnvelopeItems.count)
        guard let profileItem = envelope.additionalEnvelopeItems.first else {
            throw(TestError.noProfileEnvelopeItem)
        }

        XCTAssertEqual("profile", profileItem.header.type)
        return profileItem.data
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

        let profileData = try getProfileData()
        self.assertValidProfileData(data: profileData, transactionEnvironment: transactionEnvironment, shouldTimeout: shouldTimeOut)

        if shouldTimeOut {
            kSentryProfilerTimeoutInterval = originalTimeoutInterval
        }
    }

    func assertMetricsPayload(expectedCPUUsages: [Double], usageReadings: Int, expectedMemoryFootprint: SentryRAMBytes, expectedSlowFrameCount: Int, expectedFrozenFrameCount: Int, expectedFrameRateCount: Int) throws {
        let profileData = try self.getProfileData()
        guard let profile = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] else {
            throw TestError.unexpectedProfileDeserializationType
        }
        guard let measurements = profile["measurements"] as? [String: Any] else {
            throw TestError.unexpectedMeasurementsDeserializationType
        }

        for (i, expectedUsage) in expectedCPUUsages.enumerated() {
            let key = NSString(format: kSentryMetricProfilerSerializationKeyCPUUsageFormat as NSString, i) as String
            try assertMetricValue(measurements: measurements, key: key, numberOfReadings: usageReadings, expectedValue: expectedUsage)
        }

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, numberOfReadings: usageReadings, expectedValue: expectedMemoryFootprint)

#if !os(macOS)
        let dummyValue: UInt64? = nil
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, numberOfReadings: expectedSlowFrameCount, expectedValue: dummyValue)
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, numberOfReadings: expectedFrozenFrameCount, expectedValue: dummyValue)
        try assertMetricValue(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, numberOfReadings: expectedFrameRateCount, expectedValue: dummyValue)
#endif
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, numberOfReadings: Int, expectedValue: T?) throws {
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
        }
    }

    func assertValidProfileData(data: Data, transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeout: Bool = false) {
        let profile = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(profile["version"])
        if let timestampString = profile["timestamp"] as? String {
            XCTAssertNotNil(NSDate.sentry_from(iso8601String: timestampString))
        } else {
            XCTFail("Expected a top-level timestamp")
        }

        let device = profile["device"] as? [String: Any?]
        XCTAssertNotNil(device)
        XCTAssertEqual("Apple", device!["manufacturer"] as! String)
        XCTAssertEqual(device!["locale"] as! String, (NSLocale.current as NSLocale).localeIdentifier)
        XCTAssertFalse((device!["model"] as! String).isEmpty)
#if targetEnvironment(simulator)
        XCTAssertTrue(device!["is_emulator"] as! Bool)
#else
        XCTAssertFalse(device!["is_emulator"] as! Bool)
#endif

        let os = profile["os"] as? [String: Any?]
        XCTAssertNotNil(os)
        XCTAssertNotNil(os?["name"] as? String)
        XCTAssertFalse((os!["version"] as! String).isEmpty)
        XCTAssertFalse((os!["build_number"] as! String).isEmpty)

        XCTAssertEqual("cocoa", profile["platform"] as! String)

        XCTAssertEqual(transactionEnvironment, profile["environment"] as! String)

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let releaseString = "\(bundleID)@\(version)+\(build)"
        XCTAssertEqual(profile["release"] as! String, releaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["profile_id"] as! String))

        let images = (profile["debug_meta"] as! [String: Any])["images"] as! [[String: Any]]
        XCTAssertFalse(images.isEmpty)
        let firstImage = images[0]
        XCTAssertFalse((firstImage["code_file"] as! String).isEmpty)
        XCTAssertFalse((firstImage["debug_id"] as! String).isEmpty)
        XCTAssertFalse((firstImage["image_addr"] as! String).isEmpty)
        XCTAssertGreaterThan((firstImage["image_size"] as! Int), 0)
        XCTAssertEqual(firstImage["type"] as! String, "macho")

        let sampledProfile = profile["profile"] as! [String: Any]
        let threadMetadata = sampledProfile["thread_metadata"] as! [String: [String: Any]]
        let queueMetadata = sampledProfile["queue_metadata"] as! [String: Any]
        XCTAssertFalse(threadMetadata.isEmpty)
        XCTAssertFalse(threadMetadata.values.compactMap { $0["priority"] }.filter { ($0 as! Int) > 0 }.isEmpty)
        XCTAssertFalse(queueMetadata.isEmpty)
        XCTAssertFalse(((queueMetadata.first?.value as! [String: Any])["label"] as! String).isEmpty)

        let samples = sampledProfile["samples"] as! [[String: Any]]
        XCTAssertFalse(samples.isEmpty)

        let frames = sampledProfile["frames"] as! [[String: Any]]
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse((frames[0]["instruction_addr"] as! String).isEmpty)
        XCTAssertFalse((frames[0]["function"] as! String).isEmpty)

        let stacks = sampledProfile["stacks"] as! [[Int]]
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

        let transactions = profile["transactions"] as? [[String: Any]]
        XCTAssertEqual(transactions!.count, 1)
        for transaction in transactions! {
            XCTAssertEqual(fixture.transactionName, transaction["name"] as! String)
            XCTAssertNotNil(transaction["id"])
            if let idString = transaction["id"] {
                XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: idString as! String))
            }
            XCTAssertNotNil(transaction["trace_id"])
            if let traceIDString = transaction["trace_id"] {
                XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: traceIDString as! String))
            }
            XCTAssertNotNil(transaction["trace_id"])
            XCTAssertNotNil(transaction["relative_start_ns"])
            XCTAssertFalse((transaction["relative_end_ns"] as! NSString).isEqual(to: "0"))
            XCTAssertNotNil(transaction["active_thread_id"])
        }

        for sample in samples {
            XCTAssertNotNil(sample["elapsed_since_start_ns"] as! String)
            XCTAssertNotNil(sample["thread_id"])
            XCTAssertNotNil(stacks[sample["stack_id"] as! Int])
        }

        if shouldTimeout {
            XCTAssertEqual(profile["truncation_reason"] as! String, profilerTruncationReasonName(.timeout))
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

            switch expectedDecision {
            case .undecided, .no:
                XCTAssertEqual(0, self.fixture.client.captureEventWithScopeInvocations.first!.additionalEnvelopeItems.count)
            case .yes:
                guard let event = self.fixture.client.captureEventWithScopeInvocations.first else {
                    XCTFail("Expected to capture at least 1 event")
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
