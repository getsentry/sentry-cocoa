@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryHangTrackingIntegrationTests: SentrySDKIntegrationTestsBase {

    private static let dsn = TestConstants.dsnAsString(username: "SentryANRTrackingIntegrationTests")

    private class Fixture {
        let options: Options

        let currentDate = TestCurrentDateProvider()
        let debugImageProvider = TestDebugImageProvider()
        let infoPlistWrapper = TestInfoPlistWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let mockTracker = MockAppHangTracker()

        private var originalExtensionDetector: SentryExtensionDetector!

        init() {
            options = Options()
            options.dsn = SentryHangTrackingIntegrationTests.dsn
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 4.5
            options.releaseName = "release-name-test"

            debugImageProvider.debugImages = [TestData.debugImage]
        }

        func setUpDI(extensionDetector: SentryExtensionDetector) throws {
            SentryDependencyContainer.sharedInstance().fileManager = try TestFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
            originalExtensionDetector = SentryDependencyContainer.sharedInstance().extensionDetector
            SentryDependencyContainer.sharedInstance().extensionDetector = extensionDetector
        }

        func tearDownDI() throws {
            SentryDependencyContainer.sharedInstance().fileManager = nil
            if let extensionDetector = originalExtensionDetector {
                SentryDependencyContainer.sharedInstance().extensionDetector = extensionDetector
            }
        }
    }

    private var fixture: Fixture!
    private var sut: SentryHangTrackingIntegration<SentryDependencyContainer>?

    override var options: Options {
        self.fixture.options
    }

    override func setUp() {
        super.setUp()
        fixture = Fixture()

        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = fixture.dispatchQueueWrapper
        SentryDependencyContainer.sharedInstance().debugImageProvider = fixture.debugImageProvider
        SentryDependencyContainer.sharedInstance().appHangTracker = fixture.mockTracker
    }

    override func tearDownWithError() throws {
        sut?.uninstall()

        try fixture.tearDownDI()

        clearTestState()
        super.tearDown()
    }

    private func hangTracker(with options: Options) -> SentryHangTrackingIntegration<SentryDependencyContainer>? {
        SentryHangTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
    }

    func testWhenInitialized_IntegrationIsNotNil() {
        givenInitializedTracker()
        XCTAssertNotNil(sut)
    }

    func test_enableAppHangsTracking_Disabled() {
        let options = Options()
        options.enableAppHangTracking = false

        let result = hangTracker(with: options)
        XCTAssertNil(result)
    }

    func test_appHangsTimeoutInterval_Zero() {
        let options = Options()
        options.enableAppHangTracking = true
        options.appHangTimeoutInterval = 0

        let result = hangTracker(with: options)
        XCTAssertNil(result)
    }

#if os(macOS)
    func testHangStarted_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

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

            XCTAssertGreaterThan(threadsWithFrames, 1, "Not enough threads with frames")

            XCTAssertEqual(event?.debugMeta?.count, 1)
            let eventDebugImage = try XCTUnwrap(event?.debugMeta?.first)
            XCTAssertEqual(eventDebugImage.debugID, TestData.debugImage.debugID)
        }
    }

    func testHangStarted_DetectingPausedResumed_EventCaptured() throws {
        setUpThreadInspector()
        givenInitializedTracker()
        try XCTUnwrap(sut).pauseAppHangTracking()
        try XCTUnwrap(sut).resumeAppHangTracking()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            let ex = try XCTUnwrap(event?.exceptions?.first, "ANR Exception not found")

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
        }
    }
#endif // os(macOS)

    func testHangStarted_DetectingPaused_NoEventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        try XCTUnwrap(sut).pauseAppHangTracking()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        assertNoEventCaptured()
    }

    func testCallPauseResumeOnMultipleThreads_DoesNotCrash() {
        givenInitializedTracker()

        testConcurrentModifications(asyncWorkItems: 100, writeLoopCount: 10, writeWork: {_ in
            self.sut?.pauseAppHangTracking()
            self.fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))
        }, readWork: {
            self.sut?.resumeAppHangTracking()
            self.fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))
        })
    }

    func testHangStarted_ButNoThreads_EventNotCaptured() {
        givenInitializedTracker()
        setUpThreadInspector(addThreads: false)

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        assertNoEventCaptured()
    }

#if os(iOS) || os(tvOS)
    func testHangStarted_ButBackground_EventNotCaptured() {

        givenInitializedTracker()
        setUpThreadInspector()
        let backgroundUIApplication = TestSentryUIApplication()
        backgroundUIApplication.unsafeApplicationState = .background
        SentryDependencyContainer.sharedInstance().applicationOverride = backgroundUIApplication

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        assertNoEventCaptured()
    }
#endif // os(iOS) || os(tvOS)

    func testDealloc_CallsUninstall() throws {
        givenInitializedTracker()

        func initIntegration() {
            let _ = hangTracker(with: self.options)
        }

        initIntegration()

        XCTAssertEqual(1, fixture.mockTracker.observerCount)
    }

#if os(iOS) || os(tvOS)
    func testV2_HangStarted_StoresAppHangEventInFile() throws {
        // Arrange
        options.releaseName = "my-release-name-test"
        options.environment = "testing-environment"
        options.dist = "adhoc"
        setUpThreadInspector()
        givenInitializedTracker()

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        // Assert
        let event = try XCTUnwrap(SentrySDKInternal.currentHub().client()?.fileManager.readAppHangEvent())
        XCTAssertEqual(event.releaseName, "my-release-name-test")
        XCTAssertEqual(event.environment, "testing-environment")
        XCTAssertEqual(event.dist, "adhoc")
        let appContext = try XCTUnwrap(event.context?["app"] as? [String: Any])
        XCTAssertEqual(true, appContext["in_foreground"] as? Bool)
        XCTAssertEqual(true, appContext["is_active"] as? Bool)
    }

    func testV2_HangStarted_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        // Assert
        assertNoEventCaptured()
    }

    func testV2_HangEnded_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        // This must not impact on the stored event
        SentrySDK.configureScope { scope in
            scope.setTag(value: "value2", key: "key")
        }

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

        // Assert
        try assertEventWithScopeCaptured { event, scope, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging between 0.0 and 2.0 seconds.")

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

            XCTAssertEqual(event?.releaseName, "release-name-test")
        }
    }

    func testV2_HangStartedThenPaused_HangEnded_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        try XCTUnwrap(sut).pauseAppHangTracking()

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

        // Assert
        try assertEventWithScopeCaptured { event, scope, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hang Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging between 0.0 and 2.0 seconds.")

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

            XCTAssertEqual(event?.releaseName, "release-name-test")
        }
    }

    func testV2_HangEnded_EmptyEventStored_DoesCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

        SentrySDKInternal.currentHub().client()?.fileManager.storeAppHang(Event())

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

        // Assert
        assertNoEventCaptured()
    }

    func testV2_HangStarted_StopNotCalled_SendsFatalAppHangOnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

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

            XCTAssertEqual(ex.type, "Fatal App Hang Fully Blocked")
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

            XCTAssertEqual(event?.releaseName, "release-name-test")
        }
    }

    func testV2_HangStarted_PauseCalledButStopNotCalled_SendsFatalAppHangOnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))
        try XCTUnwrap(sut).pauseAppHangTracking()

        // Act
        givenInitializedTracker()
        try XCTUnwrap(sut).pauseAppHangTracking()

        // Assert
        try assertFatalEventWithScope { event, _ in
            XCTAssertEqual(event?.level, SentryLevel.fatal)

            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.handled, false)

            XCTAssertEqual(ex.type, "Fatal App Hang Fully Blocked")
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

            XCTAssertEqual(event?.releaseName, "release-name-test")
        }
    }

    func testV2_HangStarted_StopNotCalledAndAbnormalSession_SendsFatalAppHangOnNextInstall() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

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
        XCTAssertEqual(ex.type, "Fatal App Hang Fully Blocked")
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

        XCTAssertEqual(event.releaseName, "release-name-test")
    }

    func testV2_HangStarted_StopNotCalledAndCrashed_SendsNormalAppHangEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))

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

    func testV2_StoredAppHangEventWithNoException_NoEventCaptured() throws {
        // Arrange
        givenInitializedTracker()
        let event = Event()
        SentrySDKInternal.currentHub().client()?.fileManager.storeAppHang(event)

        // Act
        givenInitializedTracker()

        // Assert
        assertNoEventCaptured()
    }

    func testV2_HangEnded_DoesDeleteTheAppHangEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

        // Act
        let _ = hangTracker(with: self.options)

        // Assert
        try assertEventWithScopeCaptured { event, _, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.value, "App hanging between 0.0 and 2.0 seconds.")
        }
    }

    func testV2_HangEnded_ButEventDeleted_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        fixture.mockTracker.simulateHang(SentryAppHang(duration: 4.5, state: .started))
        SentrySDKInternal.currentHub().client()?.fileManager.deleteAppHangEvent()

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

        // Assert
        assertNoEventCaptured()
    }
#endif //  os(iOS) || os(tvOS)

    func testHangEnded_WithoutPriorStart_DoesNotCaptureEvent() throws {
        // Arrange
        setUpThreadInspector()
        givenInitializedTracker()

        // Act
        fixture.mockTracker.simulateHang(SentryAppHang(duration: 2.0, state: .ended))

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

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNotNil(sut, "Should install when not running in an extension")
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

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNil(sut, "Should not install when running in a Widget extension")
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

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNil(sut, "Should not install when running in an Intent extension")
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

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNil(sut, "Should not install when running in an Action extension")
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

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNil(sut, "Should not install when running in a Share extension")
    }

    func testInstall_runningInNotificationServiceExtension_shouldNotInstall() throws {
        // Arrange
        fixture.infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.usernotifications.service"]
        )
        try fixture.setUpDI(
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: fixture.infoPlistWrapper)
        )

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNil(sut, "Should not install when running in a Notification Service Extension")
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
            XCTAssertNoThrow(try fixture.tearDownDI())
        }

        let sut = hangTracker(with: options)

        // Assert
        XCTAssertNotNil(sut, "Should install when running in an unknown extension type")
    }

    private func givenInitializedTracker(crashedLastLaunch: Bool = false) {
        givenSdkWithHub()

        SentrySDK.configureScope { scope in
            scope.setTag(value: "value", key: "key")
        }
        let crumb = Breadcrumb()
        crumb.message = "crumb"
        SentrySDK.addBreadcrumb(crumb)

        self.crashWrapper.internalCrashedLastLaunch = crashedLastLaunch
        sut = hangTracker(with: self.options)
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

        SentryDependencyContainer.sharedInstance().threadInspector = threadInspector
    }
}

// MARK: - Mock Infrastructure

private class MockAppHangTracker: SentryAppHangTracker {
    private var observers = [SentryAppHangTrackerObserverToken: SentryAppHangTrackerHandler]()

    func addObserver(threshold: TimeInterval, handler: @escaping SentryAppHangTrackerHandler) -> SentryAppHangTrackerObserverToken {
        let token = SentryAppHangTrackerObserverToken()
        observers[token] = handler
        return token
    }

    func removeObserver(token: SentryAppHangTrackerObserverToken) {
        observers.removeValue(forKey: token)
    }

    func simulateHang(_ hang: SentryAppHang) {
        for handler in observers.values {
            handler(hang)
        }
    }

    var observerCount: Int {
        observers.count
    }
}
