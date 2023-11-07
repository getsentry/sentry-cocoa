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

    func testCaptureEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))

        let envelope = TestConstants.envelope
        PrivateSentrySDKOnly.capture(envelope)

        XCTAssertEqual(1, client?.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, client?.captureEnvelopeInvocations.first)
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

#if SENTRY_HAS_UIKIT
    func testGetAppStartMeasurement() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        XCTAssertEqual(appStartMeasurement, PrivateSentrySDKOnly.appStartMeasurement)

        SentrySDK.setAppStartMeasurement(nil)
        XCTAssertNil(PrivateSentrySDKOnly.appStartMeasurement)
    }
#endif // SENTRY_HAS_UIKIT

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
        displayLink.givenFrames(slow, frozen, normal)

        let currentFrames = PrivateSentrySDKOnly.currentScreenFrames
        XCTAssertEqual(UInt(slow + frozen + normal), currentFrames.total)
        XCTAssertEqual(UInt(frozen), currentFrames.frozen)
        XCTAssertEqual(UInt(slow), currentFrames.slow)
    }

    #endif
}
