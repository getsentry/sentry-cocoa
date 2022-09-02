import XCTest


#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
class SentryProfilerTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryProfilerTests")
    private static let dsn = TestConstants.dsn(username: "SentryProfilerTests")

    private class Fixture {
        let options: Options
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User wants to crash", userInfo: nil)
        var client: TestClient!
        let crumb = Breadcrumb(level: .error, category: "default")
        let scope = Scope()
        let message = "some message"
        let event: Event
        let currentDateProvider = TestCurrentDateProvider()
        let sentryCrash = TestSentryCrashWrapper.sharedInstance()
        let fileManager: SentryFileManager
        let crashedSession: SentrySession
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        let random = TestRandom(value: 0.5)

        init() {
            options = Options()
            options.dsn = SentryProfilerTests.dsnAsString

            scope.add(crumb)

            event = Event()
            event.message = SentryMessage(formatted: message)

            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDateProvider)

            CurrentDate.setCurrentDateProvider(currentDateProvider)

            crashedSession = SentrySession(releaseName: "1.0.0")
            crashedSession.endCrashed(withTimestamp: currentDateProvider.date())
            crashedSession.environment = options.environment
        }

        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }

        func getSut(_ options: Options, _ scope: Scope? = nil) -> SentryHub {
            client = TestClient(options: options)
            let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: sentryCrash, andCurrentDateProvider: currentDateProvider)
            hub.bindClient(client)
            return hub
        }
    }

    private var fixture: Fixture!
    func assertProfilesSampler(expectedDecision: SentrySampleDecision, options: (Options) -> Void) {
        let fixtureOptions = fixture.options
        fixtureOptions.tracesSampleRate = 1.0
        options(fixtureOptions)

        let hub = fixture.getSut()
        Dynamic(hub).tracesSampler.random = TestRandom(value: 1.0)
        Dynamic(hub).profilesSampler.random = TestRandom(value: 0.5)

        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        span.finish()

        guard let additionalEnvelopeItems = fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
            XCTFail("Expected to capture at least 1 event")
            return
        }
        switch expectedDecision {
        case .undecided, .no:
            XCTAssertEqual(0, additionalEnvelopeItems.count)
        case .yes:
            XCTAssertEqual(1, additionalEnvelopeItems.count)
        @unknown default:
            fatalError("Unexpected value for sample decision")
        }
    }

    func testStartTransaction_ProfilingDataIsValid() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampler = {(_: SamplingContext) -> NSNumber in
            return 1
        }
        let hub = fixture.getSut(options)
        let profileExpectation = expectation(description: "collects profiling data")
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        // Give it time to collect a profile, otherwise there will be no samples.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            guard let additionalEnvelopeItems = self.fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
                XCTFail("Expected to capture at least 1 event")
                return
            }
            XCTAssertEqual(1, additionalEnvelopeItems.count)
            guard let profileItem = additionalEnvelopeItems.first else {
                XCTFail("Expected at least 1 additional envelope item")
                return
            }
            XCTAssertEqual("profile", profileItem.header.type)
            self.assertValidProfileData(data: profileItem.data, customFields: ["environment": kSentryDefaultEnvironment])
            profileExpectation.fulfill()
        }

        // Some busy work to try and get it to show up in the profile.
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }

        waitForExpectations(timeout: 5.0) {
            if let error = $0 {
                print(error)
            }
        }
    }

    func testProfilingDataContainsEnvironmentSetFromOptions() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampler = {(_: SamplingContext) -> NSNumber in
            return 1
        }
        let expectedEnvironment = "test-environment"
        options.environment = expectedEnvironment
        let hub = fixture.getSut(options)
        let profileExpectation = expectation(description: "collects profiling data")
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        // Give it time to collect a profile, otherwise there will be no samples.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            guard let additionalEnvelopeItems = self.fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
                XCTFail("Expected to capture at least 1 event")
                return
            }
            XCTAssertEqual(1, additionalEnvelopeItems.count)
            guard let profileItem = additionalEnvelopeItems.first else {
                XCTFail("Expected at least 1 additional envelope item")
                return
            }
            XCTAssertEqual("profile", profileItem.header.type)
            self.assertValidProfileData(data: profileItem.data, customFields: ["environment": expectedEnvironment])
            profileExpectation.fulfill()
        }

        // Some busy work to try and get it to show up in the profile.
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }

        waitForExpectations(timeout: 5.0) {
            if let error = $0 {
                print(error)
            }
        }
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScope() {
        let options = fixture.options
        options.profilesSampleRate = 1.0
        options.tracesSampler = {(_: SamplingContext) -> NSNumber in
            return 1
        }
        let expectedEnvironment = "test-environment"
        let hub = fixture.getSut(options)
        hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        let profileExpectation = expectation(description: "collects profiling data")
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        // Give it time to collect a profile, otherwise there will be no samples.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            guard let additionalEnvelopeItems = self.fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
                XCTFail("Expected to capture at least 1 event")
                return
            }
            XCTAssertEqual(1, additionalEnvelopeItems.count)
            guard let profileItem = additionalEnvelopeItems.first else {
                XCTFail("Expected at least 1 additional envelope item")
                return
            }
            XCTAssertEqual("profile", profileItem.header.type)
            self.assertValidProfileData(data: profileItem.data, customFields: ["environment": expectedEnvironment])
            profileExpectation.fulfill()
        }

        // Some busy work to try and get it to show up in the profile.
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }

        waitForExpectations(timeout: 5.0) {
            if let error = $0 {
                print(error)
            }
        }
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

    private func assertValidProfileData(data: Data, customFields: [String: String]) {
        let profile = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual("Apple", profile["device_manufacturer"] as! String)
        XCTAssertEqual("cocoa", profile["platform"] as! String)
        XCTAssertEqual(fixture.transactionName, profile["transaction_name"] as! String)
#if os(iOS)
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

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["transaction_id"] as! String))
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["profile_id"] as! String))
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["trace_id"] as! String))

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
        for (key, expectedValue) in customFields {
            guard let actualValue = profile[key] as? String else {
                XCTFail("Expected value not present in profile")
                continue
            }
            XCTAssertEqual(expectedValue, actualValue)
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
