@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryANRTrackingIntegrationTests: SentrySDKIntegrationTestsBase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryANRTrackingIntegrationTests")
    
    private class Fixture {
        let options: Options
        
        let currentDate = TestCurrentDateProvider()
        let debugImageProvider = TestDebugImageProvider()
        let infoPlistWrapper = TestInfoPlistWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        private var originalExtensionDetector: SentryExtensionDetector!

        init() {
            options = Options()
            options.dsn = SentryANRTrackingIntegrationTests.dsn
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 4.5

            debugImageProvider.debugImages = [TestData.debugImage]
        }

        func setUpDI(extensionDetector: SentryExtensionDetector) throws {
            SentryDependencyContainer.sharedInstance().fileManager = try TestFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueueWrapper
            )

            originalExtensionDetector = Dependencies.extensionDetector
            Dependencies.extensionDetector = extensionDetector
        }

        func tearDownDI() throws {
            SentryDependencyContainer.sharedInstance().fileManager = nil
            if let extensionDetector = originalExtensionDetector {
                Dependencies.extensionDetector = extensionDetector
            }
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryANRTrackingIntegration!
    
    override var options: Options {
        self.fixture.options
    }
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()

        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = fixture.dispatchQueueWrapper
        SentryDependencyContainer.sharedInstance().debugImageProvider = fixture.debugImageProvider
    }
    
    override func tearDownWithError() throws {
        sut?.uninstall()

        try fixture.tearDownDI()
        
        clearTestState()
        super.tearDown()
    }

    func testWhenBeingTraced_TrackerNotInitialized() {
        givenInitializedTracker(isBeingTraced: true)
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }

    func testWhenNoDebuggerAttached_TrackerInitialized() throws {
        givenInitializedTracker()
        
        let tracker = try XCTUnwrap(Dynamic(sut).tracker.asAnyObject as? SentryANRTracker)

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        XCTAssertTrue(tracker.helper is SentryANRTrackerV2, "Expected SentryANRTrackerV2, but got \(type(of: tracker))")
#else
        XCTAssertTrue(tracker.helper is SentryANRTrackerV1, "Expected SentryANRTrackerV1 on macOS, but got \(type(of: tracker))")
#endif
    }
    
    func test_enableAppHangsTracking_Disabled() {
        let options = Options()
        options.enableAppHangTracking = false
        
        sut = SentryANRTrackingIntegration()
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
    
    func test_appHangsTimeoutInterval_Zero() {
        let options = Options()
        options.enableAppHangTracking = true
        options.appHangTimeoutInterval = 0
        
        sut = SentryANRTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }

#if os(macOS)
    func testV1_ANRDetected_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }
            
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hanging")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)
            
            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }
            
            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count
            
            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)
        }
    }
    
    func testV1_ANRDetected_FullyBlocking_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)

            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }

            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count

            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)
        }
    }

    func testV1_ANRDetected_NonFullyBlocked_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Non Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            XCTAssertNil(ex.mechanism?.data)
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)

            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }

            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count

            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)
        }
    }
    
    func testV1_ANRDetected_Unknown_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hanging")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            XCTAssertNil(ex.mechanism?.data)
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)

            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }

            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count

            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)
        }
    }

    func testANRDetected_DetectingPausedResumed_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        sut.resumeAppHangTracking()

        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            let ex = try XCTUnwrap(event?.exceptions?.first, "ANR Exception not found")

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
        }
    }
#endif // os(macOS)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testANRDetected_NonFullyBlockedDisabled_EventNotCaptured() throws {
        fixture.options.enableReportNonFullyBlockingAppHangs = false
        givenInitializedTracker()
        setUpThreadInspector()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)

        assertNoEventCaptured()
    }
#endif
    
    func testANRDetected_DetectingPaused_NoEventCaptured() {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
        assertNoEventCaptured()
    }

    func testCallPauseResumeOnMultipleThreads_DoesNotCrash() {
        givenInitializedTracker()
        
        testConcurrentModifications(asyncWorkItems: 100, writeLoopCount: 10, writeWork: {_ in
            self.sut.pauseAppHangTracking()
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.unknown)
        }, readWork: {
            self.sut.resumeAppHangTracking()
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.unknown)
        })
    }
    
    func testANRDetected_ButNoThreads_EventNotCaptured() {
        givenInitializedTracker()
        setUpThreadInspector(addThreads: false)
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
        assertNoEventCaptured()
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testANRDetected_ButBackground_EventNotCaptured() {

        givenInitializedTracker()
        setUpThreadInspector()
        let backgroundUIApplication = TestSentryUIApplication()
        backgroundUIApplication.unsafeApplicationState = .background
        SentryDependencyContainer.sharedInstance().applicationOverride = backgroundUIApplication

        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)

        assertNoEventCaptured()
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testDealloc_CallsUninstall() throws {
        givenInitializedTracker()
        
        // // So ARC deallocates the SentryANRTrackingIntegration
        func initIntegration() {
            self.crashWrapper.internalIsBeingTraced = false
            let sut = SentryANRTrackingIntegration()
            sut.install(with: self.options)
        }
        
        initIntegration()
        
        let tracker = SentryDependencyContainer.sharedInstance().getANRTracker(self.options.appHangTimeoutInterval)
        
        let listeners = try XCTUnwrap(Dynamic(tracker.helper).listeners.asObject as? NSHashTable<NSObject>)
        
        XCTAssertEqual(1, listeners.count)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testV2_ANRDetected_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()
        
        // Act
        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        
        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRStopped_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        // This must not impact on the stored event
        SentrySDK.configureScope { scope in
            scope.setTag(value: "value2", key: "key")
        }

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.851, maxDuration: 2.249)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        try assertEventWithScopeCaptured { event, scope, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging between 1.9 and 2.2 seconds.")
            
            // We use the mechanism data to temporarily store the duration.
            // This asserts that we remove the mechanism data before sending the event.
            let mechanismData = try XCTUnwrap(ex.mechanism?.data)
            XCTAssertTrue(mechanismData.isEmpty)
            
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)

            let tags = try XCTUnwrap(event?.tags)
            XCTAssertEqual(1, tags.count)
            XCTAssertEqual("value", tags["key"])
            
            let breadcrumbs = try XCTUnwrap(event?.breadcrumbs)
            XCTAssertEqual(1, breadcrumbs.count)
            XCTAssertEqual("crumb", breadcrumbs.first?.message)
            
            // Ensure we capture the event with an empty scope
            XCTAssertEqual(scope?.tags.count, 0)
            XCTAssertEqual(scope?.breadcrumbs().count, 0)
        }
    }

    func testV2Detected_PauseCalled_ANRStopped_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)

        sut.pauseAppHangTracking()

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.851, maxDuration: 2.249)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        try assertEventWithScopeCaptured { event, scope, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging between 1.9 and 2.2 seconds.")

            // We use the mechanism data to temporarily store the duration.
            // This asserts that we remove the mechanism data before sending the event.
            let mechanismData = try XCTUnwrap(ex.mechanism?.data)
            XCTAssertTrue(mechanismData.isEmpty)

            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)

            let tags = try XCTUnwrap(event?.tags)
            XCTAssertEqual(1, tags.count)
            XCTAssertEqual("value", tags["key"])

            let breadcrumbs = try XCTUnwrap(event?.breadcrumbs)
            XCTAssertEqual(1, breadcrumbs.count)
            XCTAssertEqual("crumb", breadcrumbs.first?.message)

            // Ensure we capture the event with an empty scope
            XCTAssertEqual(scope?.tags.count, 0)
            XCTAssertEqual(scope?.breadcrumbs().count, 0)
        }
    }

    func testV2_ANRStopped_EmptyEventStored_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        SentrySDKInternal.currentHub().client()?.fileManager.storeAppHang(Event())

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.851, maxDuration: 2.249)
        Dynamic(sut).anrStoppedWithResult(result)
        
        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRDetected_StopNotCalled_SendsFatalANROnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        
        // This must not impact on the stored event
        SentrySDK.configureScope { scope in
            scope.setTag(value: "value2", key: "key")
        }
        
        // Act
        givenInitializedTracker()
        
        // Assert
        try assertFatalEventWithScope { event, _ in
            XCTAssertEqual(event?.level, SentryLevel.fatal)

            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.handled, false)

            XCTAssertEqual(ex.type, "Fatal App Hang Non Fully Blocked")
            XCTAssertEqual(ex.value, "The user or the OS watchdog terminated your app while it blocked the main thread for at least 4500 ms.")
            
            // We use the mechanism data to temporarily store the duration.
            // This asserts that we remove the mechanism data before sending the event.
            let mechanismData = try XCTUnwrap(ex.mechanism?.data)
            XCTAssertTrue(mechanismData.isEmpty)
            
            let tags = try XCTUnwrap(event?.tags)
            XCTAssertEqual(1, tags.count)
            XCTAssertEqual("value", tags["key"])
            
            let breadcrumbs = try XCTUnwrap(event?.breadcrumbs)
            XCTAssertEqual(1, breadcrumbs.count)
            XCTAssertEqual("crumb", breadcrumbs.first?.message)
        }
    }

    func testV2_ANRDetected_PauseCalledButStopNotCalled_SendsFatalANROnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        sut.pauseAppHangTracking()

        // Act
        givenInitializedTracker()
        sut.pauseAppHangTracking()

        // Assert
        try assertFatalEventWithScope { event, _ in
            XCTAssertEqual(event?.level, SentryLevel.fatal)

            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.handled, false)

            XCTAssertEqual(ex.type, "Fatal App Hang Non Fully Blocked")
            XCTAssertEqual(ex.value, "The user or the OS watchdog terminated your app while it blocked the main thread for at least 4500 ms.")

            // We use the mechanism data to temporarily store the duration.
            // This asserts that we remove the mechanism data before sending the event.
            let mechanismData = try XCTUnwrap(ex.mechanism?.data)
            XCTAssertTrue(mechanismData.isEmpty)

            let tags = try XCTUnwrap(event?.tags)
            XCTAssertEqual(1, tags.count)
            XCTAssertEqual("value", tags["key"])

            let breadcrumbs = try XCTUnwrap(event?.breadcrumbs)
            XCTAssertEqual(1, breadcrumbs.count)
            XCTAssertEqual("crumb", breadcrumbs.first?.message)
        }
    }

    func testV2_ANRDetected_StopNotCalledAndAbnormalSession_SendsFatalAppHangOnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        
        // This must not impact on the stored event
        SentrySDK.configureScope { scope in
            scope.setTag(value: "value2", key: "key")
        }
        
        let abnormalSession = SentrySession(releaseName: "release", distinctId: "distinct")
        abnormalSession.endAbnormal(withTimestamp: fixture.currentDate.date())
        SentrySDKInternal.currentHub().client()?.fileManager.storeAbnormalSession(abnormalSession)
        
        // Act
        givenInitializedTracker()
        
        // Assert
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        
        XCTAssertEqual(1, client.captureFatalEventWithSessionInvocations.count, "Wrong number of `Crashs` captured.")
        let capture = try XCTUnwrap(client.captureFatalEventWithSessionInvocations.first)
        let event = capture.event
        XCTAssertEqual(event.level, SentryLevel.fatal)
        
        let ex = try XCTUnwrap(event.exceptions?.first)
        XCTAssertEqual(ex.type, "Fatal App Hang Non Fully Blocked")
        XCTAssertEqual(ex.value, "The user or the OS watchdog terminated your app while it blocked the main thread for at least 4500 ms.")
        
        // We use the mechanism data to temporarily store the duration.
        // This asserts that we remove the mechanism data before sending the event.
        let mechanismData = try XCTUnwrap(ex.mechanism?.data)
        XCTAssertTrue(mechanismData.isEmpty)
        
        let tags = try XCTUnwrap(event.tags)
        XCTAssertEqual(1, tags.count)
        XCTAssertEqual("value", tags["key"])
        
        let breadcrumbs = try XCTUnwrap(event.breadcrumbs)
        XCTAssertEqual(1, breadcrumbs.count)
        XCTAssertEqual("crumb", breadcrumbs.first?.message)
        
        let actualSession = try XCTUnwrap(capture.session)
        XCTAssertEqual("release", actualSession.releaseName)
        XCTAssertEqual("distinct", actualSession.distinctId)
        XCTAssertEqual(fixture.currentDate.date(), actualSession.timestamp)
        XCTAssertEqual("anr_foreground", actualSession.abnormalMechanism)
    }
    
    func testV2_ANRDetected_StopNotCalledAndCrashed_SendsNormalAppHangEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        // Act
        givenInitializedTracker(crashedLastLaunch: true)
        
        // Assert
        try assertEventWithScopeCaptured { event, scope, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            
            // Ensure we capture the event with an empty scope
            XCTAssertEqual(scope?.tags.count, 0)
            XCTAssertEqual(scope?.breadcrumbs().count, 0)
        }
    }
    
    func testV2_StoredApHangEventWithNoException_NoEventCaptured() throws {
        // Arrange
        givenInitializedTracker()
        let event = Event()
        SentrySDKInternal.currentHub().client()?.fileManager.storeAppHang(event)
        
        // Act
        givenInitializedTracker()
        
        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRStopped_DoesDeleteTheAppHangEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        let result = SentryANRStoppedResult(minDuration: 1.849, maxDuration: 2.251)
        Dynamic(sut).anrStoppedWithResult(result)

        // Act
        sut.install(with: self.options)
        
        // Assert
        try assertEventWithScopeCaptured { event, _, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.value, "App hanging between 1.8 and 2.3 seconds.")
        }
    }
    
    func testV2_ANRStopped_ButEventDeleted_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        SentrySDKInternal.currentHub().client()?.fileManager.deleteAppHangEvent()

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.8, maxDuration: 2.2)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRStoppedWithNilResult_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        // Act
        Dynamic(sut).anrStoppedWithResult(nil)

        // Assert
        assertNoEventCaptured()
    }
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testV1_ANRStopped_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.8, maxDuration: 2.2)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        assertNoEventCaptured()
    }

    func testEventIsNotANR() {
        XCTAssertFalse(Event().isAppHangEvent)
    }

    func testInstall_notRunningInExtension_shouldInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: SentryInfoPlistKey.extension.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.extension.rawValue)
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()
        
        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertTrue(result, "Should install when not running in an extension")
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject, "Tracker should be initialized")
    }
    
    func testInstall_runningInWidgetExtension_shouldNotInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()

        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertFalse(result, "Should not install when running in a Widget extension")
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject, "Tracker should not be initialized")
    }
    
    func testInstall_runningInIntentExtension_shouldNotInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.intents-service"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()

        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertFalse(result, "Should not install when running in an Intent extension")
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject, "Tracker should not be initialized")
    }
    
    func testInstall_runningInActionExtension_shouldNotInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.ui-services"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()

        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertFalse(result, "Should not install when running in an Action extension")
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject, "Tracker should not be initialized")
    }
    
    func testInstall_runningInShareExtension_shouldNotInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.share-services"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()

        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertFalse(result, "Should not install when running in a Share extension")
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject, "Tracker should not be initialized")
    }
    
    func testInstall_runningInUnknownExtension_shouldInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.unknown-extension"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )
        defer {
            try? fixture.tearDownDI()
        }
        crashWrapper.internalIsBeingTraced = false

        sut = SentryANRTrackingIntegration()

        // Act
        let result = sut.install(with: options)
        
        // Assert
        XCTAssertTrue(result, "Should install when running in an unknown extension type")
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject, "Tracker should be initialized")
    }
    
    private func givenInitializedTracker(isBeingTraced: Bool = false, crashedLastLaunch: Bool = false) {
        givenSdkWithHub()
        
        SentrySDK.configureScope { scope in
            scope.setTag(value: "value", key: "key")
        }
        let crumb = Breadcrumb()
        crumb.message = "crumb"
        SentrySDK.addBreadcrumb(crumb)
        
        self.crashWrapper.internalIsBeingTraced = isBeingTraced
        self.crashWrapper.internalCrashedLastLaunch = crashedLastLaunch
        sut = SentryANRTrackingIntegration()
        sut.install(with: self.options)
    }
    
    private func setUpThreadInspector(addThreads: Bool = true) {
        let threadInspector = TestThreadInspector.instance

        if addThreads {
            
            let frame1 = Sentry.Frame()
            
            let thread1 = SentryThread(threadId: 0)
            thread1.stacktrace = SentryStacktrace(frames: [frame1], registers: [:])
            thread1.current = true
            
            let frame2 = Sentry.Frame()
            
            let thread2 = SentryThread(threadId: 1)
            thread2.stacktrace = SentryStacktrace(frames: [frame2], registers: [:])
            thread2.current = false
            
            threadInspector.allThreads = [
                thread2,
                thread1
            ]
        } else {
            threadInspector.allThreads = []
        }

        Dependencies.threadInspector = threadInspector
    }
}
