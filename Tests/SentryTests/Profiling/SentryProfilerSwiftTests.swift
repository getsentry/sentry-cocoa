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
        lazy var client: TestClient! = TestClient(options: options)
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
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryTracer.resetAppStartMeasurementRead()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
        SentryTracer.resetAppStartMeasurementRead()
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        SentryFramesTracker.sharedInstance().resetFrames()
        SentryFramesTracker.sharedInstance().stop()
#endif
    }

    func testConcurrentProfilingTransactions() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0

        let numberOfTransactions = 10
        var spans = [Span]()
        for _ in 0 ..< numberOfTransactions {
            spans.append(fixture.hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation))
        }

        forceProfilerSample()

        spans.forEach { $0.finish() }

        guard let envelope = self.fixture.client.captureEnvelopeInvocations.first else {
            XCTFail("Expected to capture 1 event")
            return
        }
        XCTAssertEqual(1, envelope.items.count)
        guard let profileItem = envelope.items.first else {
            XCTFail("Expected an envelope item")
            return
        }
        XCTAssertEqual("profile", profileItem.header.type)
        self.assertValidProfileData(data: profileItem.data, numberOfTransactions: numberOfTransactions)
    }

    /// Test a situation where a long-running span starts the profiler, which winds up timing out, and then another span starts that begins a new profile, then finishes, and then the long-running span finishes; both profiles should be separately captured in envelopes.
    /// ```
    ///    time                0s                         1s     2s     2.5s     3s  (these times are adjusted to the 1s profile timeout for testing only)
    ///    transaction A       |---------------------------------------------------|
    ///    profiler A          |---------------------------x  <- timeout
    ///    transaction B                                           |-------|
    ///    profiler B                                              |-------|  <- normal finish
    ///   ```
    func testConcurrentSpansWithTimeout() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0

        let spanA = fixture.hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)

        forceProfilerSample()

        // cause spanA profiler to time out
        let exp = expectation(description: "spanA times out")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3)

        let spanB = self.fixture.hub.startTransaction(name: self.fixture.transactionName, operation: self.fixture.transactionOperation)

        forceProfilerSample()

        spanB.finish()
        spanA.finish()

        XCTAssertEqual(self.fixture.client.captureEnvelopeInvocations.count, 2)
        var currentEnvelope = 0
        for envelope in self.fixture.client.captureEnvelopeInvocations.invocations {
            XCTAssertEqual(1, envelope.items.count)
            guard let profileItem = envelope.items.first else {
                XCTFail("Expected an envelope item")
                return
            }
            XCTAssertEqual("profile", profileItem.header.type)
            self.assertValidProfileData(data: profileItem.data, shouldTimeout: currentEnvelope == 1)
            currentEnvelope += 1
        }
    }

    func testProfileTimeoutTimer() {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        performTest(shouldTimeOut: true)
    }

    func testStartTransaction_ProfilingDataIsValid() {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        performTest()
    }

    func testProfilingDataContainsEnvironmentSetFromOptions() {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        performTest(transactionEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScope() {
        fixture.options.profilesSampleRate = 1.0
        fixture.options.tracesSampleRate = 1.0
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        performTest(transactionEnvironment: expectedEnvironment)
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
    /// Keep a thread busy over a long enough period of time (long enough for 3 samples) for the sampler to pick it up.
    func forceProfilerSample() {
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }
    }

    func performTest(transactionEnvironment: String = kSentryDefaultEnvironment, numberOfTransactions: Int = 1, shouldTimeOut: Bool = false) {
        let span = fixture.hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)

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

        guard let envelope = self.fixture.client.captureEnvelopeInvocations.first else {
            XCTFail("Expected to capture at least 1 event")
            return
        }
        XCTAssertEqual(1, envelope.items.count)
        guard let profileItem = envelope.items.first else {
            XCTFail("Expected an envelope item")
            return
        }
        XCTAssertEqual("profile", profileItem.header.type)
        self.assertValidProfileData(data: profileItem.data, transactionEnvironment: transactionEnvironment, numberOfTransactions: numberOfTransactions, shouldTimeout: shouldTimeOut)

    }

    func assertValidProfileData(data: Data, transactionEnvironment: String = kSentryDefaultEnvironment, numberOfTransactions: Int = 1, shouldTimeout: Bool = false) {
        let profile = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual("Apple", profile["device_manufacturer"] as! String)
        XCTAssertEqual("cocoa", profile["platform"] as! String)
        XCTAssertNotNil(profile["transactions"])
        if let transactions = profile["transactions"] as? [[String: String]] {
            XCTAssertEqual(transactions.count, numberOfTransactions)
            for transaction in transactions {
                XCTAssertEqual(fixture.transactionName, transaction["name"])
                XCTAssertNotNil(transaction["id"])
                if let idString = transaction["id"] {
                    XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: idString))
                }
                XCTAssertNotNil(transaction["trace_id"])
                if let traceIDString = transaction["trace_id"] {
                    XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: traceIDString))
                }
                XCTAssertEqual(transactionEnvironment, transaction["environment"])
                XCTAssertNotNil(transaction["trace_id"])
                XCTAssertNotNil(transaction["relative_start_ns"])
                XCTAssertNotNil(transaction["relative_end_ns"])
            }
        } else {
            XCTFail("Transaction information in profile payload not of expected type.")
        }
#if targetEnvironment(macCatalyst)
        XCTAssertEqual("iPadOS", profile["device_os_name"] as! String)
        XCTAssertFalse((profile["device_os_version"] as! String).isEmpty)
#elseif os(iOS)
        XCTAssertEqual("iOS", profile["device_os_name"] as! String)
        XCTAssertFalse((profile["device_os_version"] as! String).isEmpty)
#endif
        XCTAssertFalse((profile["device_os_build_number"] as! String).isEmpty)
        XCTAssertFalse((profile["device_locale"] as! String).isEmpty)
        XCTAssertFalse((profile["device_model"] as! String).isEmpty)
#if os(iOS) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(profile["device_is_emulator"] as! Bool)
#else
        XCTAssertFalse(profile["device_is_emulator"] as! Bool)
#endif
        XCTAssertFalse((profile["device_physical_memory_bytes"] as! String).isEmpty)
        XCTAssertFalse((profile["version_code"] as! String).isEmpty)
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["profile_id"] as! String))

        let images = (profile["debug_meta"] as! [String: Any])["images"] as! [[String: Any]]
        XCTAssertFalse(images.isEmpty)
        let firstImage = images[0]
        XCTAssertFalse((firstImage["code_file"] as! String).isEmpty)
        XCTAssertFalse((firstImage["debug_id"] as! String).isEmpty)
        XCTAssertFalse((firstImage["image_addr"] as! String).isEmpty)
        XCTAssertGreaterThan((firstImage["image_size"] as! Int), 0)
        XCTAssertEqual(firstImage["type"] as! String, "macho")

        let sampledProfile = profile["sampled_profile"] as! [String: Any]
        let threadMetadata = sampledProfile["thread_metadata"] as! [String: [String: Any]]
        let queueMetadata = sampledProfile["queue_metadata"] as! [String: Any]

        XCTAssertFalse(threadMetadata.isEmpty)
        XCTAssertFalse(threadMetadata.values.compactMap { $0["priority"] }.filter { ($0 as! Int) > 0 }.isEmpty)
        XCTAssertFalse(threadMetadata.values.filter { $0["is_main_thread"] as? Bool == true }.isEmpty)
        XCTAssertFalse(queueMetadata.isEmpty)
        XCTAssertFalse(((queueMetadata.first?.value as! [String: Any])["label"] as! String).isEmpty)

        let samples = sampledProfile["samples"] as! [[String: Any]]
        XCTAssertFalse(samples.isEmpty)
        let frames = samples[0]["frames"] as! [[String: Any]]
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse((frames[0]["instruction_addr"] as! String).isEmpty)
        XCTAssertFalse((frames[0]["function"] as! String).isEmpty)
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

        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        let exp = expectation(description: "Span finishes")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            switch expectedDecision {
            case .undecided, .no:
                XCTAssertEqual(0, self.fixture.client.captureEnvelopeInvocations.count)
            case .yes:
                guard let envelope = self.fixture.client.captureEnvelopeInvocations.first else {
                    XCTFail("Expected to capture at least 1 event")
                    return
                }
                XCTAssertEqual(1, envelope.items.count)
            @unknown default:
                fatalError("Unexpected value for sample decision")
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: 3)
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
