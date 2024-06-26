import SentryTestUtils
import XCTest

class PrivateSentrySDKOnlyTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testStoreEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        let envelope = TestConstants.envelope
        PrivateSentrySDKOnly.store(envelope)

        XCTAssertEqual(1, client?.storedEnvelopeInvocations.count)
        XCTAssertEqual(envelope, client?.storedEnvelopeInvocations.first)
    }
    
    func testStoreEnvelopeWithUndhandled_MarksSessionAsCrashedAndDoesNotStartNewSession() throws {
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        hub.setTestSession()
        let sessionToBeCrashed = hub.session

        let envelope = getUnhandledExceptionEnvelope()
        PrivateSentrySDKOnly.store(envelope)
        
        let storedEnvelope = client?.storedEnvelopeInvocations.first
        let attachedSessionData = storedEnvelope!.items.last!.data
        let attachedSession = try XCTUnwrap(try! JSONSerialization.jsonObject(with: attachedSessionData) as? [String: Any])
        
        XCTAssertEqual(0, hub.startSessionInvocations)
        // Assert crashed session was attached to the envelope
        XCTAssertEqual(sessionToBeCrashed!.sessionId.uuidString, try XCTUnwrap(attachedSession["sid"] as? String))
        XCTAssertEqual("crashed", try XCTUnwrap(attachedSession["status"] as? String))
    }
    
    func testCaptureEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        let envelope = TestConstants.envelope
        PrivateSentrySDKOnly.capture(envelope)

        XCTAssertEqual(1, client?.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, client?.captureEnvelopeInvocations.first)
    }
    
    func testCaptureEnvelopeWithUndhandled_MarksSessionAsCrashedAndStartsNewSession() throws {
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        hub.setTestSession()
        let sessionToBeCrashed = hub.session

        let envelope = getUnhandledExceptionEnvelope()
        PrivateSentrySDKOnly.capture(envelope)

        let capturedEnvelope = client?.captureEnvelopeInvocations.first
        let attachedSessionData = capturedEnvelope!.items.last!.data
        let attachedSession = try XCTUnwrap(try! JSONSerialization.jsonObject(with: attachedSessionData) as? [String: Any])
        
        // Assert new session was started
        XCTAssertEqual(1, hub.startSessionInvocations)
        // Assert crashed session was attached to the envelope
        XCTAssertEqual(sessionToBeCrashed!.sessionId.uuidString, try XCTUnwrap(attachedSession["sid"] as? String))
        XCTAssertEqual("crashed", try XCTUnwrap(attachedSession["status"] as? String))
    }

    func testSetSdkName() {
        let originalName = PrivateSentrySDKOnly.getSdkName()
        let name = "Some SDK name"
        let originalVersion = SentryMeta.versionString
        XCTAssertNotEqual(originalVersion, "")

        PrivateSentrySDKOnly.setSdkName(name)
        XCTAssertEqual(SentryMeta.sdkName, name)
        XCTAssertEqual(SentryMeta.versionString, originalVersion)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkName(), name)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkVersionString(), originalVersion)

        PrivateSentrySDKOnly.setSdkName(originalName)
        XCTAssertEqual(SentryMeta.sdkName, originalName)
        XCTAssertEqual(SentryMeta.versionString, originalVersion)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkName(), originalName)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkVersionString(), originalVersion)
    }

    func testSetSdkNameAndVersion() {
        let originalName = PrivateSentrySDKOnly.getSdkName()
        let originalVersion = PrivateSentrySDKOnly.getSdkVersionString()
        let name = "Some SDK name"
        let version = "1.2.3.4"

        PrivateSentrySDKOnly.setSdkName(name, andVersionString: version)
        XCTAssertEqual(SentryMeta.sdkName, name)
        XCTAssertEqual(SentryMeta.versionString, version)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkName(), name)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkVersionString(), version)

        PrivateSentrySDKOnly.setSdkName(originalName, andVersionString: originalVersion)
        XCTAssertEqual(SentryMeta.sdkName, originalName)
        XCTAssertEqual(SentryMeta.versionString, originalVersion)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkName(), originalName)
        XCTAssertEqual(PrivateSentrySDKOnly.getSdkVersionString(), originalVersion)

    }

    func testEnvelopeWithData() throws {
        let itemData = "{}\n{\"length\":0,\"type\":\"attachment\"}\n".data(using: .utf8)!
        XCTAssertNotNil(PrivateSentrySDKOnly.envelope(with: itemData))
    }

    func testGetDebugImages() {
        let images = PrivateSentrySDKOnly.getDebugImages()

        // Only make sure we get some images. The actual tests are in
        // SentryDebugImageProviderTests
        XCTAssertGreaterThan(images.count, 100)
    }

    #if canImport(UIKit)
    func testGetAppStartMeasurement() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm, runtimeInitSystemTimestamp: 1)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        XCTAssertEqual(appStartMeasurement, PrivateSentrySDKOnly.appStartMeasurement)

        SentrySDK.setAppStartMeasurement(nil)
        XCTAssertNil(PrivateSentrySDKOnly.appStartMeasurement)
    }

    func testGetAppStartMeasurementWithSpansCold() throws {
        SentrySDK.setAppStartMeasurement(
            TestData.getAppStartMeasurement(type: .cold, runtimeInitSystemTimestamp: 1)
        )

        let actualAppStartMeasurement = try XCTUnwrap(PrivateSentrySDKOnly.appStartMeasurementWithSpans())
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["type"] as? String), "cold")
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["is_pre_warmed"] as? Int), 0)
        let spans = try XCTUnwrap(actualAppStartMeasurement["spans"] as? NSArray)
        XCTAssertEqual(spans.count, 1)
        let firstSpan = try XCTUnwrap(spans.firstObject as? NSDictionary)
        XCTAssertEqual(try XCTUnwrap(firstSpan["description"] as? String), "UIKit init")
        XCTAssert(firstSpan["start_timestamp_ms"] is NSNumber)
        XCTAssert(firstSpan["end_timestamp_ms"] is NSNumber)
    }

    func testGetAppStartMeasurementWithSpansPreWarmed() throws {
        SentrySDK.setAppStartMeasurement(
            TestData.getAppStartMeasurement(
                type: .warm,
                runtimeInitSystemTimestamp: 1,
                preWarmed: true)
        )

        let actualAppStartMeasurement = try XCTUnwrap(PrivateSentrySDKOnly.appStartMeasurementWithSpans())
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["type"] as? String), "warm")
        XCTAssertEqual( try XCTUnwrap(actualAppStartMeasurement["is_pre_warmed"] as? Int), 1)

        var spans = try XCTUnwrap(actualAppStartMeasurement["spans"] as? [NSDictionary])
        XCTAssertEqual(spans.count, 3)

        let span0 = try XCTUnwrap(spans.first)
        XCTAssertEqual(span0["description"] as? String, "Pre Runtime Init")
        XCTAssertTrue(span0["start_timestamp_ms"] is NSNumber)
        XCTAssertTrue(span0["end_timestamp_ms"] is NSNumber)
        
        spans = [NSDictionary](spans.dropFirst())

        let span1 = try XCTUnwrap(spans.first)
        XCTAssertEqual(span1["description"] as? String, "Runtime init to Pre Main initializers")
        XCTAssertTrue(span1["start_timestamp_ms"] is NSNumber)
        XCTAssertTrue(span1["end_timestamp_ms"] is NSNumber)

        spans = [NSDictionary](spans.dropFirst())
        
        let span2 = try XCTUnwrap(spans.first)
        XCTAssertEqual(span2["description"] as? String, "UIKit init")
        XCTAssertTrue(span2["start_timestamp_ms"] is NSNumber)
        XCTAssertTrue(span2["end_timestamp_ms"] is NSNumber)
    }

    func testGetAppStartMeasurementWithSpansReturnsTimestampsInMs() throws {
        SentrySDK.setAppStartMeasurement(
            TestData.getAppStartMeasurement(
                type: .cold,
                appStartTimestamp: Date(timeIntervalSince1970: 5),
                runtimeInitSystemTimestamp: 1,
                preWarmed: true,
                moduleInitializationTimestamp: Date(timeIntervalSince1970: 20),
                runtimeInitTimestamp: Date(timeIntervalSince1970: 15),
                sdkStartTimestamp: Date(timeIntervalSince1970: 10))
        )

        let actualAppStartMeasurement = try XCTUnwrap(PrivateSentrySDKOnly.appStartMeasurementWithSpans())
            
        XCTAssertTrue(actualAppStartMeasurement["app_start_timestamp_ms"] is NSNumber)
        XCTAssertTrue(actualAppStartMeasurement["runtime_init_timestamp_ms"] is NSNumber)
        XCTAssertTrue(actualAppStartMeasurement["module_initialization_timestamp_ms"] is NSNumber)
        XCTAssertTrue(actualAppStartMeasurement["sdk_start_timestamp_ms"] is NSNumber)
        
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["app_start_timestamp_ms"] as? NSNumber), 5_000)
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["runtime_init_timestamp_ms"] as? NSNumber), 15_000)
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["module_initialization_timestamp_ms"] as? NSNumber), 20_000)
        XCTAssertEqual(try XCTUnwrap(actualAppStartMeasurement["sdk_start_timestamp_ms"] as? NSNumber), 10_000)
    }
    #endif

    func testGetInstallationId() {
        XCTAssertEqual(SentryInstallation.id(withCacheDirectoryPath: PrivateSentrySDKOnly.options.cacheDirectoryPath), PrivateSentrySDKOnly.installationID)
    }

    func testSendAppStartMeasurement() {
        XCTAssertFalse(PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode)

        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        XCTAssertTrue(PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode)
    }

    func testOptions() {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        let client = TestClient(options: options)
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        XCTAssertEqual(PrivateSentrySDKOnly.options, options)
    }

    func testDefaultOptions() {
        XCTAssertNotNil(PrivateSentrySDKOnly.options)
        XCTAssertNil(PrivateSentrySDKOnly.options.dsn)
        XCTAssertEqual(PrivateSentrySDKOnly.options.enabled, true)
    }

    #if !os(tvOS) && !os(watchOS)
    /**
      * Smoke Tests profiling via PrivateSentrySDKOnly. Actual profiling unit tests are done elsewhere.
     */
    func testProfilingStartAndCollect() throws {
        if sentry_threadSanitizerIsPresent() {
            throw XCTSkip("Profiler does not run if thread sanitizer is attached.")
        }
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        let client = TestClient(options: options)
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        let traceIdA = SentryId()

        let startTime = PrivateSentrySDKOnly.startProfiler(forTrace: traceIdA)
        XCTAssertGreaterThan(startTime, 0)
        Thread.sleep(forTimeInterval: 0.2)
        let payload = PrivateSentrySDKOnly.collectProfileBetween(startTime, and: startTime + 200_000_000, forTrace: traceIdA)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["platform"] as? String, "cocoa")
        XCTAssertNotNil(payload?["debug_meta"])
        XCTAssertNotNil(payload?["device"])
        XCTAssertNotNil(payload?["profile_id"])
        let profile = payload?["profile"] as? NSDictionary
        XCTAssertNotNil(profile?["thread_metadata"])
        XCTAssertNotNil(profile?["samples"])
        XCTAssertNotNil(profile?["stacks"])
        XCTAssertNotNil(profile?["frames"])
        let transactionInfo = payload?["transaction"] as? NSDictionary
        XCTAssertNotNil(transactionInfo)
        XCTAssertGreaterThan(try XCTUnwrap(transactionInfo?["active_thread_id"] as? Int64), 0)
    }

    func testProfilingDiscard() {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        let client = TestClient(options: options)
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        let traceIdA = SentryId()

        let startTime = PrivateSentrySDKOnly.startProfiler(forTrace: traceIdA)
        XCTAssertGreaterThan(startTime, 0)
        Thread.sleep(forTimeInterval: 0.2)
        PrivateSentrySDKOnly.discardProfiler(forTrace: traceIdA)
        // how can we test that that this fails with an NCAssert failure?
        //        XCTAssertThrowsError(
        //            PrivateSentrySDKOnly.collectProfileBetween(
        //            startTime, and: startTime + 200_000_000, forTrace: traceIdA)
        //        ) { error in
        //            XCTAssertTrue(error is NSException)
        //        }
    }
    #endif

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testIsFramesTrackingRunning() {
        XCTAssertFalse(PrivateSentrySDKOnly.isFramesTrackingRunning)
        SentryDependencyContainer.sharedInstance().framesTracker.start()
        XCTAssertTrue(PrivateSentrySDKOnly.isFramesTrackingRunning)
    }

    func testGetFrames() {
        let tracker = SentryDependencyContainer.sharedInstance().framesTracker
        let displayLink = TestDisplayLinkWrapper()

        tracker.setDisplayLinkWrapper(displayLink)
        tracker.start()
        displayLink.call()

        let slow = 2
        let frozen = 1
        let normal = 100
        displayLink.renderFrames(slow, frozen, normal)

        let currentFrames = PrivateSentrySDKOnly.currentScreenFrames
        XCTAssertEqual(UInt(slow + frozen + normal), currentFrames.total)
        XCTAssertEqual(UInt(frozen), currentFrames.frozen)
        XCTAssertEqual(UInt(slow), currentFrames.slow)
    }

    #endif

    #if canImport(UIKit)
    func testCaptureReplayShouldCallReplayIntegration() {
        guard #available(iOS 16.0, tvOS 16.0, *) else { return }

        let options = Options()
        options.setIntegrations([TestSentrySessionReplayIntegration.self])
        SentrySDK.start(options: options)

        PrivateSentrySDKOnly.captureReplay()

        XCTAssertTrue(TestSentrySessionReplayIntegration.captureReplayShouldBeCalledAtLeastOnce())
    }

    func testGetReplayIdShouldBeNil() {
        XCTAssertNil(PrivateSentrySDKOnly.getReplayId())
    }

    func testGetReplayIdShouldExist() {
        let client = TestClient(options: Options())
        let scope = Scope()
        scope.replayId = VALID_REPLAY_ID
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: scope))

        XCTAssertEqual(PrivateSentrySDKOnly.getReplayId(), VALID_REPLAY_ID)
    }

    func testAddReplayIgnoreClassesShouldNotFailWhenReplayIsAvailable() {
        let options = Options()
        options.setIntegrations([TestSentrySessionReplayIntegration.self])
        SentrySDK.start(options: options)

        PrivateSentrySDKOnly.addReplayIgnoreClasses([UILabel.self])
    }

    func testAddReplayRedactShouldNotFailWhenReplayIsAvailable() {
        let options = Options()
        options.setIntegrations([TestSentrySessionReplayIntegration.self])
        SentrySDK.start(options: options)

        PrivateSentrySDKOnly.addReplayRedactClasses([UILabel.self])
    }

    let VALID_REPLAY_ID = "0eac7ab503354dd5819b03e263627a29"

    private class TestSentrySessionReplayIntegration: SentrySessionReplayIntegration {
        static var captureReplayCalledTimes = 0

        override func install(with options: Options) -> Bool {
            return true
        }

        override func captureReplay() {
            TestSentrySessionReplayIntegration.captureReplayCalledTimes += 1
        }

        static func captureReplayShouldBeCalledAtLeastOnce() -> Bool {
            return captureReplayCalledTimes > 0
        }
    }
    #endif
    
    func getUnhandledExceptionEnvelope() -> SentryEnvelope {
        let event = Event()
        event.message = SentryMessage(formatted: "Test Event with unhandled exception")
        event.level = .error
        event.exceptions = [TestData.exception]
        event.exceptions?.first?.mechanism?.handled = false
        return SentryEnvelope(event: event)
    }
}
