@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
// swiftlint:disable file_length
import Foundation
import XCTest

#if os(iOS) || os(tvOS)

class SentrySessionReplayIntegrationTests: XCTestCase {

    private var uiApplication: TestSentryUIApplication!
    private var globalEventProcessor: SentryGlobalEventProcessor!
    private var dateProvider: TestCurrentDateProvider!
    private var captureScheduler: DefaultSentrySessionReplayRunLoopCaptureScheduler<TestSessionReplayRunLoopObserver>!
    private var createdObservationBlock: ((TestSessionReplayRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var observationBlock: ((TestSessionReplayRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private let testObserver = TestSessionReplayRunLoopObserver()
    private let currentRunLoopMode = RunLoop.Mode.default

    private struct TestSessionReplayRunLoopObserver: SentryRunLoopObserver { }
    
    override func setUpWithError() throws {
        guard #available(iOS 16.0, tvOS 16.0, *) else {
            throw XCTSkip("iOS version not supported")
        }

        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 26.0, *) {
            throw XCTSkip(
                "Creating UIWindow in an unhosted Mac Catalyst test throws "
                    + "NSInternalInconsistencyException on macOS 26 and later."
            )
        }
        #endif

        uiApplication = TestSentryUIApplication()
        globalEventProcessor = SentryGlobalEventProcessor()
        uiApplication.windows = [UIWindow()]
        dateProvider = TestCurrentDateProvider()
        captureScheduler = DefaultSentrySessionReplayRunLoopCaptureScheduler<TestSessionReplayRunLoopObserver>(
            createObserver: { [unowned self] _, _, _, _, block in
                self.createdObservationBlock = block
                return self.testObserver
            },
            addObserver: { [unowned self] _, _, _ in self.observationBlock = self.createdObservationBlock },
            removeObserver: { [unowned self] _, _, _ in self.observationBlock = nil },
            currentRunLoopMode: { [unowned self] in self.currentRunLoopMode }
        )

        SentryDependencyContainer.sharedInstance().applicationOverride = uiApplication
        SentryDependencyContainer.sharedInstance().reachability = TestSentryReachability()
        SentryDependencyContainer.sharedInstance().globalEventProcessor = globalEventProcessor
        SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
        SentryDependencyContainer.sharedInstance().sessionReplayCaptureScheduler = captureScheduler
    }
    
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    private func getSut() throws -> SentrySessionReplayIntegration {
        return try XCTUnwrap(SentrySDKInternal.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration)
    }

    private func waitForReplayCommand() {
        let commandExpectation = expectation(description: "Replay command executed")
        DispatchQueue.main.async { commandExpectation.fulfill() }
        wait(for: [commandExpectation], timeout: 1)
    }
    
    private func startSDK(sessionSampleRate: Float, errorSampleRate: Float, enableSwizzling: Bool = true, noIntegrations: Bool = false, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = "https://user@test.com/test"
            $0.removeAllIntegrations()
            if !noIntegrations {
                $0.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, onErrorSampleRate: errorSampleRate)
            }
            $0.enableSwizzling = enableSwizzling
            $0.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
            configure?($0)
        }
        SentrySDKInternal.currentHub().startSession()
    }
    
    func testInstallWithZeroSampleRates_shouldRemainIdle() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        let sut = try getSut()
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(globalEventProcessor.processors.count, 1)
        XCTAssertNil(sut.sessionReplay)
        XCTAssertFalse(try XCTUnwrap(sut.getTouchTracker()).isEnabled)
    }
    
    func testInstallFullSessionReplay() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(globalEventProcessor.processors.count, 1)
    }

    func testCurrentReplayInfo_whenSessionMode_shouldPersistMode() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)

        XCTAssertEqual(try currentReplayInfo()["replayType"] as? String, "session")
    }

    func testCurrentReplayInfo_whenBufferMode_shouldPersistMode() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)

        XCTAssertEqual(try currentReplayInfo()["replayType"] as? String, "buffer")
    }

    func testCurrentReplayInfo_whenBufferConvertsToSession_shouldUpdateMode() throws {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncExecutesBlock = false
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let asyncCallsBeforeCapture = dispatchQueue.dispatchAsyncCalled

        XCTAssertTrue(try XCTUnwrap(getSut().sessionReplay).captureReplay())
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, asyncCallsBeforeCapture + 1)
        let currentInfo = try currentReplayInfo()
        XCTAssertEqual(currentInfo["replayType"] as? String, "buffer")

        sentrySessionReplaySync_writeInfo()
        var crashInfo = SentryCrashReplay()
        let sessionPath = try XCTUnwrap(currentInfo["path"] as? String)
        let crashInfoPath = "\(replayFolder())/\(sessionPath)/crashInfo"
        XCTAssertTrue(sentrySessionReplaySync_readInfo(&crashInfo, crashInfoPath))
        XCTAssertEqual(SentryReplayType(crashReplayType: crashInfo.replayType), .session)

        dispatchQueue.invokeLastDispatchAsync()
        XCTAssertEqual(try currentReplayInfo()["replayType"] as? String, "session")
    }

    func testCurrentReplayInfo_whenQueuedUpdateIsStale_shouldNotUpdateNewReplay() throws {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
        let fileManager = try SentryFileManager(
            options: options,
            dateProvider: dateProvider,
            dispatchQueueWrapper: dispatchQueue
        )
        let sut = SessionReplayFileManager(fileManager: fileManager, sharedDispatchQueue: dispatchQueue)

        let firstReplayId = SentryId()
        let firstDirectory = try XCTUnwrap(sut.createSessionDirectory())
        sut.saveCurrentSessionInfo(
            firstReplayId,
            path: firstDirectory.path,
            options: options.sessionReplay,
            replayType: .buffer
        )
        sut.updateCurrentReplayType(.session, replayId: firstReplayId)

        let secondReplayId = SentryId()
        let secondDirectory = try XCTUnwrap(sut.createSessionDirectory())
        sut.saveCurrentSessionInfo(
            secondReplayId,
            path: secondDirectory.path,
            options: options.sessionReplay,
            replayType: .buffer
        )
        dispatchQueue.invokeLastDispatchAsync()

        let currentInfo = try currentReplayInfo()
        XCTAssertEqual(currentInfo["replayId"] as? String, secondReplayId.sentryIdString)
        XCTAssertEqual(currentInfo["replayType"] as? String, "buffer")
    }

    func testRunLoopScheduler_whenStaleStopRunsAfterNewStart_shouldKeepNewObserver() {
        let oldToken = NSObject()
        let newToken = NSObject()
        var oldCaptures = 0
        var newCaptures = 0

        captureScheduler.start(token: oldToken) { _ in oldCaptures += 1 }
        captureScheduler.start(token: newToken) { _ in newCaptures += 1 }
        captureScheduler.stop(token: oldToken)

        observationBlock?(testObserver, .afterWaiting)
        observationBlock?(testObserver, .beforeWaiting)

        XCTAssertEqual(oldCaptures, 0)
        XCTAssertEqual(newCaptures, 1)
    }
    
    func testInstallNoSwizzlingNoTouchTracker() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0, enableSwizzling: false)
        guard let integration = SentrySDKInternal.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        else {
            XCTFail("Could not find session replay integration")
            return
        }
        XCTAssertNil(integration.getTouchTracker())
    }
    
    func testInstallWithSwizzlingHasTouchTracker() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        XCTAssertNotNil(sut.getTouchTracker())
    }
    
    func testInstallFullSessionReplayButDontRunBecauseOfRandom() throws {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.3)
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(globalEventProcessor.processors.count, 1)
        let sut = try getSut()
        XCTAssertNil(sut.sessionReplay)
    }

    func testApplicationDidBecomeActive_whenStartIsNotPending_shouldNotStartReplay() throws {
        // -- Arrange --
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.3)
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)

        let sut = try getSut()
        XCTAssertNil(sut.sessionReplay)

        // -- Act --
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // -- Assert --
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testInstallFullSessionReplayBecauseOfRandom() throws {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.1)
        
        startSDK(sessionSampleRate: 0.3, errorSampleRate: 0)
        
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(globalEventProcessor.processors.count, 1)
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testInstallErrorReplay() {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0.1)
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(globalEventProcessor.processors.count, 1)
    }
    
    func testWaitForNotificationWithNoWindow() throws {
        uiApplication.windows = nil
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        
        XCTAssertNil(sut.sessionReplay)
        uiApplication.windows = [UIWindow()]
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
        XCTAssertNotNil(sut.sessionReplay)
    }

    func testRunReplayForAvailableWindow_whenPendingStartAndSessionEnds_shouldNotStartAfterLifecycleNotification() throws {
        // -- Arrange --
        uiApplication.windows = nil
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)

        let sut = try getSut()
        XCTAssertNil(sut.sessionReplay)

        // -- Act --
        SentrySDKInternal.currentHub().endSession()
        uiApplication.windows = [UIWindow()]
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        // -- Assert --
        XCTAssertNil(sut.sessionReplay)
    }

    func testApplicationDidBecomeActive_whenSessionRestartWasDelayed_shouldStartReplay() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)

        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
        SentrySDKInternal.currentHub().endSession()
        XCTAssertNil(sut.sessionReplay)
        uiApplication.windows = nil
        SentrySDKInternal.currentHub().startSession()
        XCTAssertNil(sut.sessionReplay)

        // -- Act --
        uiApplication.windows = [UIWindow()]
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // -- Assert --
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testPauseAndResumeForApplicationStateChange() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(sut.sessionReplay?.isRunning ?? true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }

    func testManualPause_whenApplicationForegrounds_shouldRemainPausedUntilManualResume() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()

        sut.pause()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertFalse(sut.sessionReplay?.isRunning ?? true)

        sut.resume()

        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }

    func testStartAfterSessionEnd_whenManuallyPaused_shouldStartNewReplay() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()

        sut.pause()
        sut.sentrySessionEnded(session: SentrySession(releaseName: "", distinctId: ""))
        sut.start()

        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }

    func testStopWhenManuallyPaused_shouldClearPauseForAutomaticSessionRestart() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()

        sut.pause()
        sut.stop()
        sut.sentrySessionStarted(session: SentrySession(releaseName: "", distinctId: ""))

        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }

    func testStartWithActiveManuallyPausedReplay_shouldRemainPaused() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)

        sut.pause()
        sut.start()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertIdentical(sut.sessionReplay, sessionReplay)
        XCTAssertFalse(sessionReplay.isRunning)
    }
    
    func testStopReplayAtEndOfSession() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
        SentrySDKInternal.currentHub().endSession()
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testStartFullSessionForError() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        
        XCTAssertFalse(sut.sessionReplay?.isFullSession ?? true)
        SentrySDK.capture(error: NSError(domain: "", code: 1))
        XCTAssertTrue(sut.sessionReplay?.isFullSession ?? false)
    }
    
    func testRestartReplayWithNewSession() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
        SentrySDKInternal.currentHub().endSession()
        XCTAssertNil(sut.sessionReplay)
        SentrySDKInternal.currentHub().startSession()
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testRestartReplayWithNewSessionClosePreviousReplay() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        SentrySDKInternal.currentHub().startSession()
        XCTAssertNotNil(sut.sessionReplay)
        let oldSessionReplay = sut.sessionReplay
        XCTAssertTrue(oldSessionReplay?.isRunning ?? false)
        SentrySDKInternal.currentHub().startSession()
        XCTAssertFalse(oldSessionReplay?.isRunning ?? true)
    }
    
    func testScreenNameFromSentryUIApplication() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        uiApplication._relevantViewControllerNames = ["Test Screen"]
        XCTAssertEqual(sut.currentScreenNameForSessionReplay(), "Test Screen")
    }
    
    func testScreenNameFromSentryScope() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        SentrySDKInternal.currentHub().configureScope { scope in
            scope.currentScreen = "Scope Screen"
        }
        
        let sut = try getSut()
        uiApplication._relevantViewControllerNames = ["Test Screen"]
        XCTAssertEqual(sut.currentScreenNameForSessionReplay(), "Scope Screen")
    }
    
    func testLegacyReplayWithoutMode_shouldInferSessionFromCrashInfo() throws {
        try createLastSessionReplay()
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        let replay = try XCTUnwrap(captureCrashReplay().replay)

        XCTAssertEqual(replay.replay.replayType, .session)
        XCTAssertEqual(replay.recording.segmentId, 2)
        XCTAssertEqual(replay.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 4))
    }

    func testSessionReplayForCrash_withCompletedSegmentAndStaleBufferType_shouldRecoverAsSession() throws {
        try createLastSessionReplay(
            errorSampleRate: 0,
            replayType: .buffer,
            crashSafeReplayType: .session
        )
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        let replay = try XCTUnwrap(captureCrashReplay().replay)

        XCTAssertEqual(replay.replay.replayType, .session)
        XCTAssertEqual(replay.recording.segmentId, 2)
    }

    func testSessionReplayForCrash_whenPromotedBeforeFirstSegment_shouldRecoverBufferedWindowAsSession() throws {
        try createLastSessionReplay(
            writeSessionInfo: false,
            errorSampleRate: 0,
            frameTimestamps: Array(1...10),
            replayType: .buffer,
            crashSafeReplayType: .session
        )
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        let replay = try XCTUnwrap(captureCrashReplay().replay)

        XCTAssertEqual(replay.replay.replayType, .session)
        XCTAssertEqual(replay.recording.segmentId, 0)
        XCTAssertEqual(replay.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 1))
    }

    func testSessionReplayForCrash_withoutCompletedSegmentAndZeroRates_shouldRecover() throws {
        try createLastSessionReplay(
            writeSessionInfo: false,
            errorSampleRate: 0,
            replayType: .session
        )
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        let result = try captureCrashReplay()
        let replay = try XCTUnwrap(result.replay)

        XCTAssertEqual(replay.replay.replayType, .session)
        XCTAssertEqual(replay.recording.segmentId, 0)
        XCTAssertEqual(
            (result.crash.context?["replay"] as? [String: Any])?["replay_id"] as? String,
            replay.replay.eventId.sentryIdString
        )
    }

    func testBufferReplayForCrash() throws {
        class CustomBreadcrumbConverter: NSObject, SentryReplayBreadcrumbConverter {
            func convert(from breadcrumb: Breadcrumb) -> (any SentryRRWebEventProtocol)? {
                guard let timestamp = breadcrumb.timestamp else { return nil }
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "custom.recovered")
            }
        }

        try createLastSessionReplay(writeSessionInfo: false)
        
        SentryDependencyContainer.sharedInstance().sessionReplayBreadcrumbConverter = CustomBreadcrumbConverter()
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        let client = SentryClientInternal(options: try XCTUnwrap(SentrySDK.startOption))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be captured")
        hub.onReplayCapture = {
            expectation.fulfill()
        }
        
        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        crash.breadcrumbs = [
            .custom(date: Date(timeIntervalSinceReferenceDate: 4)),
            .custom(date: Date(timeIntervalSinceReferenceDate: 6))
        ]
        globalEventProcessor.reportAll(crash)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 1)
        
        let replayInfo = try XCTUnwrap(hub.capturedReplayRecordingVideo.first)
        XCTAssertEqual(replayInfo.replay.replayType, SentryReplayType.buffer)
        XCTAssertEqual(replayInfo.recording.segmentId, 0)
        XCTAssertEqual(replayInfo.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 5))

        let breadcrumbs = replayInfo.recording.events.compactMap { $0 as? SentryRRWebBreadcrumbEvent }
        XCTAssertEqual(breadcrumbs.count, 1)
        XCTAssertEqual(
            (breadcrumbs.first?.data?["payload"] as? [String: Any])?["timestamp"] as? TimeInterval,
            Date(timeIntervalSinceReferenceDate: 6).timeIntervalSince1970
        )
        XCTAssertEqual((breadcrumbs.first?.data?["payload"] as? [String: Any])?["category"] as? String, "custom.recovered")
    }

    func testBufferReplayForCrashUsesConfiguredBreadcrumbConverter() throws {
        class CustomBreadcrumbConverter: NSObject, SentryReplayBreadcrumbConverter {
            func convert(from breadcrumb: Breadcrumb) -> (any SentryRRWebEventProtocol)? {
                guard let timestamp = breadcrumb.timestamp else { return nil }
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "custom.configured")
            }
        }

        try createLastSessionReplay(writeSessionInfo: false)
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        PrivateSentrySDKOnly.configureSessionReplay(with: CustomBreadcrumbConverter(), screenshotProvider: nil)

        let client = SentryClientInternal(options: try XCTUnwrap(SentrySDK.startOption))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be captured")
        hub.onReplayCapture = {
            expectation.fulfill()
        }

        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        crash.breadcrumbs = [
            .custom(date: Date(timeIntervalSinceReferenceDate: 6))
        ]
        globalEventProcessor.reportAll(crash)

        wait(for: [expectation], timeout: 1)
        let replayInfo = try XCTUnwrap(hub.capturedReplayRecordingVideo.first)
        let breadcrumbs = replayInfo.recording.events.compactMap { $0 as? SentryRRWebBreadcrumbEvent }
        XCTAssertEqual(breadcrumbs.count, 1)
        XCTAssertEqual((breadcrumbs.first?.data?["payload"] as? [String: Any])?["category"] as? String, "custom.configured")
    }

    func testBufferReplayForCrash_usesNewestFramesWhenRecoveredBufferSpansMoreThanErrorDuration() throws {
        try createLastSessionReplay(writeSessionInfo: false, frameTimestamps: [0, 50, 100])

        startSDK(sessionSampleRate: 1, errorSampleRate: 1)

        let client = SentryClientInternal(options: try XCTUnwrap(SentrySDK.startOption))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be captured")
        hub.onReplayCapture = {
            expectation.fulfill()
        }

        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        globalEventProcessor.reportAll(crash)

        wait(for: [expectation], timeout: 1)

        let replayInfo = try XCTUnwrap(hub.capturedReplayRecordingVideo.first)
        XCTAssertEqual(replayInfo.replay.replayType, SentryReplayType.buffer)
        XCTAssertEqual(replayInfo.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 71))
    }
    
    func testBufferReplayForCrash_withPersistedZeroRate_shouldNotRecover() throws {
        try createLastSessionReplay(
            writeSessionInfo: false,
            errorSampleRate: 0,
            replayType: .buffer
        )
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.5)
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)

        XCTAssertNil(try captureCrashReplay(expectCapture: false).replay)
    }
    
    func testBufferReplayIgnoredBecauseEventDroppedInBeforeSend() throws {
        try createLastSessionReplay(writeSessionInfo: false)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1, configure: { options in
            options.beforeSend = { _ in
                return nil
            }
        })
        
        let client = SentryClientInternal(options: try XCTUnwrap(SentrySDK.startOption))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be captured")
        expectation.isInverted = true
        hub.onReplayCapture = {
            expectation.fulfill()
        }
        
        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        try XCTUnwrap(client).capture(event: crash)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 0)
    }
    
    func testConnectivityChanged_whenDisconnected_shouldDispatchPauseToMainQueue() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let mainQueue = TestSentryDispatchQueueWrapper()
        mainQueue.blockBeforeMainBlock = { false }
        sut.replayProcessingQueue = mainQueue

        sut.connectivityChanged(false, typeDescription: "")

        XCTAssertEqual(mainQueue.blockOnMainInvocations.invocations.count, 1)
        XCTAssertFalse(sessionReplay.isSessionPaused)
        mainQueue.blockOnMainInvocations.invocations.first?()
        XCTAssertTrue(sessionReplay.isSessionPaused)
    }

    func testPauseSessionReplayWithReacheability() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        sut.connectivityChanged(false, typeDescription: "")
        XCTAssertTrue(sut.sessionReplay?.isSessionPaused ?? false)
        sut.connectivityChanged(true, typeDescription: "")
        XCTAssertFalse(sut.sessionReplay?.isSessionPaused ?? false)
    }

    func testConnectivityReconnect_whenApplicationPaused_shouldWaitForForeground() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)

        sut.connectivityChanged(false, typeDescription: "")
        uiApplication.unsafeApplicationState = .background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        sut.connectivityChanged(true, typeDescription: "")

        XCTAssertFalse(sessionReplay.isSessionPaused)
        XCTAssertFalse(sessionReplay.isRunning)

        uiApplication.unsafeApplicationState = .active
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertTrue(sessionReplay.isRunning)
    }

    func testConnectivityReconnect_whenApplicationForegrounded_shouldResume() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)

        sut.connectivityChanged(false, typeDescription: "")
        uiApplication.unsafeApplicationState = .background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        uiApplication.unsafeApplicationState = .active
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        sut.connectivityChanged(true, typeDescription: "")

        XCTAssertFalse(sessionReplay.isSessionPaused)
        XCTAssertTrue(sessionReplay.isRunning)
    }

    func testConnectivityReconnect_whenSdkStartedInBackground_shouldWaitForForeground() throws {
        uiApplication.unsafeApplicationState = .background
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)

        sut.connectivityChanged(false, typeDescription: "")
        sut.connectivityChanged(true, typeDescription: "")

        XCTAssertFalse(sessionReplay.isSessionPaused)
        XCTAssertFalse(sessionReplay.isRunning)

        uiApplication.unsafeApplicationState = .active
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertTrue(sessionReplay.isRunning)
    }

    func testMaskViewFromSDK() throws {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        startSDK(sessionSampleRate: 1, errorSampleRate: 1) { options in
            options.sessionReplay.maskedViewClasses = [AnotherLabel.self]
        }

        // -- Act --
        let redactBuilder = try getSut().viewPhotographer.getRedactBuilder()

        // -- Assert --
        XCTAssertTrue(redactBuilder.containsRedactClass(viewClass: AnotherLabel.self, layerClass: CALayer.self))
    }
    
    func testIgnoreViewFromSDK() throws {
        // -- Arrange --
        class AnotherLabel: UILabel {}

        startSDK(sessionSampleRate: 1, errorSampleRate: 1) { options in
            options.sessionReplay.unmaskedViewClasses = [AnotherLabel.self]
        }

        // -- Act --
        let redactBuilder = try getSut().viewPhotographer.getRedactBuilder()

        // -- Assert --
        XCTAssertTrue(redactBuilder.containsIgnoreClass(AnotherLabel.self))
    }
    
    func testStop() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
        
        SentrySDK.replay.stop()
        waitForReplayCommand()
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testStartWithIdleSessionReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0, noIntegrations: true)
        let sut = try getSut()
        XCTAssertNil(sut.sessionReplay)

        SentrySDK.replay.start()
        waitForReplayCommand()

        let sessionReplay = sut.sessionReplay
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
        XCTAssertTrue(sessionReplay?.isFullSession ?? false)
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testStartWithSessionReplayRunning() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let replayId = sessionReplay.sessionReplayId
        
        SentrySDK.replay.start()
        waitForReplayCommand()
        
        //Test whether the integration keeps the same instance of the session replay
        XCTAssertEqual(sessionReplay, sut.sessionReplay)
        //Test whether the session Id is still the same
        XCTAssertEqual(sessionReplay.sessionReplayId, replayId)
    }
    
    func testSessionReplayNewSegment_whenReplayRateLimited_shouldDispatchStopToMainQueue() throws {
        let rateLimiter = TestRateLimits()
        SentryDependencyContainer.sharedInstance().rateLimits = rateLimiter
        rateLimiter.rateLimits.append(.replay)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        let mainQueue = TestSentryDispatchQueueWrapper()
        mainQueue.blockBeforeMainBlock = { false }
        sut.replayProcessingQueue = mainQueue
        
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
  
        let videoUrl = URL(fileURLWithPath: "video.mp4")
        let videoInfo = SentryVideoInfo(path: videoUrl, height: 1_024, width: 480, duration: 5, frameCount: 5, frameRate: 1, start: Date(), end: Date(), fileSize: 10, screens: [])
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 0)
        
        sut.sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)

        XCTAssertEqual(mainQueue.blockOnMainInvocations.invocations.count, 1)
        XCTAssertNotNil(sut.sessionReplay)
        mainQueue.blockOnMainInvocations.invocations.first?()
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testStopBecauseOfAllRateLimit() throws {
        let rateLimiter = TestRateLimits()
        SentryDependencyContainer.sharedInstance().rateLimits = rateLimiter
        rateLimiter.rateLimits.append(.all)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
  
        let videoUrl = URL(fileURLWithPath: "video.mp4")
        let videoInfo = SentryVideoInfo(path: videoUrl, height: 1_024, width: 480, duration: 5, frameCount: 5, frameRate: 1, start: Date(), end: Date(), fileSize: 10, screens: [])
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 0)
        
        sut.sessionReplayNewSegment(replayEvent: replayEvent,
                                    replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                    videoUrl: videoUrl)
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testExplicitStartAfterRateLimit() throws {
        let rateLimiter = TestRateLimits()
        SentryDependencyContainer.sharedInstance().rateLimits = rateLimiter
        rateLimiter.rateLimits.append(.all)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
  
        let videoUrl = URL(fileURLWithPath: "video.mp4")
        let videoInfo = SentryVideoInfo(path: videoUrl, height: 1_024, width: 480, duration: 5, frameCount: 5, frameRate: 1, start: Date(), end: Date(), fileSize: 10, screens: [])
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 0)
        
        sut.sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
        
        sut.start()

        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }
    
    func testStartWithBufferSessionReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let replayId = sessionReplay.sessionReplayId
        
        XCTAssertFalse(sessionReplay.isFullSession)
        SentrySDK.replay.start()
        waitForReplayCommand()
        XCTAssertFalse(sessionReplay.isFullSession)
        XCTAssertEqual(sessionReplay.sessionReplayId, replayId)
    }

    func testStartBufferingWithIdleZeroRateReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)
        let sut = try getSut()

        sut.startBuffering()

        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        XCTAssertTrue(sessionReplay.isRunning)
        XCTAssertFalse(sessionReplay.isFullSession)
    }

    func testStartBufferingWithActiveBuffer_shouldKeepReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let replayId = sessionReplay.sessionReplayId

        sut.startBuffering()

        XCTAssertIdentical(sut.sessionReplay, sessionReplay)
        XCTAssertEqual(sessionReplay.sessionReplayId, replayId)
        XCTAssertFalse(sessionReplay.isFullSession)
    }

    func testFlushWithIdleZeroRateReplay_shouldStartSessionMode() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)
        let sut = try getSut()

        sut.flush()

        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        XCTAssertTrue(sessionReplay.isRunning)
        XCTAssertTrue(sessionReplay.isFullSession)
    }

    func testFlushWithBuffer_shouldPromoteWithoutSampling() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)
        let sut = try getSut()
        sut.startBuffering()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let replayId = sessionReplay.sessionReplayId

        sut.flush()

        XCTAssertIdentical(sut.sessionReplay, sessionReplay)
        XCTAssertEqual(sessionReplay.sessionReplayId, replayId)
        XCTAssertTrue(sessionReplay.isFullSession)
    }

    func testStopThenStart_shouldCreateNewReplayId() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let replayId = try XCTUnwrap(sut.sessionReplay?.sessionReplayId)

        sut.stop()
        sut.start()

        XCTAssertNotEqual(sut.sessionReplay?.sessionReplayId, replayId)
    }
    
    func testCleanUp() throws {
        // Create 3 old Sessions
        try createLastSessionReplay()
        try createLastSessionReplay()
        try createLastSessionReplay()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        
        // Start the integration with a configuration that will enable it
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        
        // Check whether there is only one old session directory and the current session directory
        let content = try FileManager.default.contentsOfDirectory(atPath: replayFolder()).filter { name in
            !name.hasPrefix("replay") && !name.hasPrefix(".") //remove replay info files and system directories
        }
        
        XCTAssertEqual(content.count, 2)
    }
    
    func testCleanUpWithNoFiles() throws {
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
        
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        SentryDependencyContainer.sharedInstance().fileManager = try SentryFileManager(
            options: options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            dispatchQueueWrapper: dispatchQueue
        )

        if FileManager.default.fileExists(atPath: replayFolder()) {
            try FileManager.default.removeItem(atPath: replayFolder())
        }
        
        // We can't use SentrySDK.start because the dependency container dispatch queue is used for other tasks.
        // Manually starting the integration and initializing it makes the test more controlled.
        _ = SentrySessionReplayIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 0)
    }
    
    func testPersistScreenshotProviderAndBreadcrumbConverter() throws {
        class CustomImageProvider: NSObject, SentryViewScreenshotProvider {
            func image(view: UIView, onComplete: @escaping Sentry.ScreenshotCallback) {
                onComplete(UIImage())
            }
        }
        
        class CustomBreadcrumbConverter: NSObject, SentryReplayBreadcrumbConverter {
            func convert(from breadcrumb: Breadcrumb) -> (any Sentry.SentryRRWebEventProtocol)? {
                return nil
            }
        }
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        PrivateSentrySDKOnly.configureSessionReplay(with: CustomBreadcrumbConverter(),
                                                    screenshotProvider: CustomImageProvider())
        let sut = try getSut()
        
        XCTAssertTrue(sut.sessionReplay?.screenshotProvider is CustomImageProvider)
        XCTAssertTrue(sut.sessionReplay?.breadcrumbConverter is CustomBreadcrumbConverter)
        
        sut.stop()
        sut.start()
        
        XCTAssertTrue(sut.sessionReplay?.screenshotProvider is CustomImageProvider)
        XCTAssertTrue(sut.sessionReplay?.breadcrumbConverter is CustomBreadcrumbConverter)
    }
    
    func testSetCustomOptions() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        PrivateSentrySDKOnly.setReplayTags(["someOption": "someValue"])
        
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        XCTAssertEqual(sessionReplay.replayTags?["someOption"] as? String, "someValue")
    }

    func testShowMaskPreviewForDebug() throws {
        let sysctl = TestSysctl()
        sysctl.internalIsBeingTraced = true
        SentryDependencyContainer.sharedInstance().sysctlWrapper = sysctl
        let window = UIWindow()
        uiApplication.windows = [window]
        
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        sut.showMaskPreview(1)
        
        XCTAssertEqual(window.subviews.count, 1, "Mask preview did not appear in production" )
        XCTAssertTrue(window.subviews.first is SentryMaskingPreviewView)
    }

    func testMaskPreview_whenSuperviewResizes_shouldResize() {
        // -- Arrange --
        let superview = UIView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let preview = SentryMaskingPreviewView(redactOptions: SentryReplayOptions())
        superview.addSubview(preview)

        // -- Act --
        superview.frame.size = .init(width: 200, height: 200)
        superview.layoutIfNeeded()

        // -- Assert --
        XCTAssertEqual(preview.frame.size, superview.bounds.size)
    }
    
    func testDontShowMaskPreviewForRelese() throws {
        let sysctl = TestSysctl()
        sysctl.internalIsBeingTraced = false
        SentryDependencyContainer.sharedInstance().sysctlWrapper = sysctl
        let window = UIWindow()
        uiApplication.windows = [window]
        
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        sut.showMaskPreview(1)
        
        XCTAssertEqual(window.subviews.count, 0, "Mask preview should not appear in production")
    }

    func testMoveCurrentReplay_whenLastFileExistsWithoutCurrent_shouldBeRemoved() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()

        let replayFolder = try XCTUnwrap(sut.replayDirectory())
        try FileManager.default.createDirectory(atPath: replayFolder.path, withIntermediateDirectories: true)

        let currentReplayPath = replayFolder.appendingPathComponent("replay.current")
        // Cleanup stale files from previous tests
        if FileManager.default.fileExists(atPath: currentReplayPath.path) {
            try FileManager.default.removeItem(atPath: currentReplayPath.path)
        }

        let lastReplayPath = replayFolder.appendingPathComponent("replay.last")
        let lastData = Data("last".utf8)
        try lastData.write(to: lastReplayPath)

        // Validate pre-condition
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentReplayPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lastReplayPath.path))

        // -- Act --
        sut.moveCurrentReplay()

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentReplayPath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: lastReplayPath.path))
    }

    func testMoveCurrentReplay_whenLastFileExistsWithCurrent_shouldBeReplaced() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()

        let replayFolder = try XCTUnwrap(sut.replayDirectory())
        try FileManager.default.createDirectory(atPath: replayFolder.path, withIntermediateDirectories: true)

        let currentReplayPath = replayFolder.appendingPathComponent("replay.current")
        let currentData = Data("current".utf8)
        try currentData.write(to: currentReplayPath)

        let lastReplayPath = replayFolder.appendingPathComponent("replay.last")
        let lastData = Data("last".utf8)
        try lastData.write(to: lastReplayPath)

        // Validate pre-condition
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentReplayPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lastReplayPath.path))

        // -- Act --
        sut.moveCurrentReplay()

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentReplayPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lastReplayPath.path))

        let writtenLastData = try Data(contentsOf: lastReplayPath)
        XCTAssertEqual(writtenLastData, currentData)
    }

    func testQueuePriorities_processingQueueShouldHaveLowerPriorityThanWorkerQueue() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()

        // -- Act --
        let processingQueue = sut.replayProcessingQueue
        let assetWorkerQueue = sut.replayAssetWorkerQueue

        // -- Assert --
        XCTAssertEqual(assetWorkerQueue.queue.label, "io.sentry.session-replay.asset-worker")
        XCTAssertEqual(assetWorkerQueue.queue.qos.qosClass, .utility)

        XCTAssertEqual(processingQueue.queue.label, "io.sentry.session-replay.processing")
        XCTAssertEqual(processingQueue.queue.qos.qosClass, .utility)

        // The actual priorities are not relevant, we just need to check that the processing queue has a lower priority
        // than the asset worker queue and that both are lower than the default priority.
        XCTAssertLessThan(processingQueue.queue.qos.relativePriority, 0)
        XCTAssertLessThan(processingQueue.queue.qos.relativePriority, assetWorkerQueue.queue.qos.relativePriority)
    }

    /// This test ensures to not have memory leaks in the SentrySessionReplayIntegration, such as a strong reference cycle.
    /// For example, removing the weak reference for accessing self when adding the globalEventProcessor would leak memory and
    /// this test would start to fail when doing so.
    func testSessionReplayIntegration_DoesNotLeakMemory() throws {

        // -- Arrange --
        weak var weakSut: SentrySessionReplayIntegration?

        // Put into extra func so ARC deallocates the sut
        func allocateSutAndDealloc() throws {
            let options = Options()
            options.sessionReplay = SentryReplayOptions(sessionSampleRate: 1.0, onErrorSampleRate: 1.0)

            let instance = SentrySessionReplayIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
            instance?.uninstall()

            weakSut = instance
        }

        // --  Act --
        try allocateSutAndDealloc()

        // -- Assert --
        XCTAssertNil(weakSut, "SentrySessionReplayIntegration should be deallocated")
    }

    func testReplayIdAndSessionReplayCleared_whenMaxDurationReached() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)

        var replayId: String?
        SentrySDKInternal.currentHub().configureScope { scope in
            replayId = scope.replayId
        }
        XCTAssertNotNil(replayId)

        // -- Act --
        // Advance time past the maximum duration (60 minutes)
        runLoopCapture()
        dateProvider.advance(by: 5)
        runLoopCapture()
        dateProvider.advance(by: 3_600)
        runLoopCapture()

        // -- Assert --
        XCTAssertFalse(sessionReplay.isRunning)
        SentrySDKInternal.currentHub().configureScope { scope in
            replayId = scope.replayId
        }
        XCTAssertNil(replayId)
        XCTAssertNil(sut.sessionReplay)
    }

    private func runLoopCapture() {
        observationBlock?(testObserver, .afterWaiting)
        observationBlock?(testObserver, .beforeWaiting)
    }

    func testReplayIdAndSessionReplayCleared_whenSessionEnds() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()

        var replayId: String?
        SentrySDKInternal.currentHub().configureScope { scope in
            replayId = scope.replayId
        }
        XCTAssertNotNil(replayId)

        // -- Act --
        sut.sessionReplayEnded()

        // -- Assert --
        SentrySDKInternal.currentHub().configureScope { scope in
            replayId = scope.replayId
        }
        XCTAssertNil(replayId)
        XCTAssertNil(sut.sessionReplay)
    }

    private func createLastSessionReplay(
        writeSessionInfo: Bool = true,
        errorSampleRate: Double = 1,
        frameTimestamps: [Int] = Array(5...9),
        replayType: SentryReplayType? = nil,
        crashSafeReplayType: SentryReplayType? = nil
    ) throws {
        let replayFolder = replayFolder()
        let jsonPath = replayFolder + "/replay.current"
        var sessionFolder = UUID().uuidString
        var info: [String: Any] = ["replayId": SentryId().sentryIdString,
                                   "path": sessionFolder,
                                   "errorSampleRate": errorSampleRate]
        if let replayType {
            info["replayType"] = replayType.toString()
        }
        let data = SentrySerializationSwift.data(withJSONObject: info)
        
        try FileManager.default.createDirectory(atPath: replayFolder, withIntermediateDirectories: true)
        
        try data?.write(to: URL(fileURLWithPath: jsonPath))
        
        sessionFolder = "\(replayFolder)/\(sessionFolder)"
        try FileManager.default.createDirectory(atPath: sessionFolder, withIntermediateDirectories: true)
                       
        for i in frameTimestamps {
            let image = UIImage.add.jpegData(compressionQuality: 1)
            try image?.write(to: URL(fileURLWithPath: "\(sessionFolder)/\(i).png") )
        }
        
        if writeSessionInfo || crashSafeReplayType != nil {
            sentrySessionReplaySync_start(
                "\(sessionFolder)/crashInfo",
                crashSafeReplayType?.crashReplayType ?? 0
            )
            if writeSessionInfo {
                sentrySessionReplaySync_updateInfo(1, Double(4))
            }
            sentrySessionReplaySync_writeInfo()
            if crashSafeReplayType == nil {
                let crashInfoURL = URL(fileURLWithPath: "\(sessionFolder)/crashInfo")
                let legacySize = MemoryLayout<UInt32>.size + MemoryLayout<Double>.size
                try Data(Data(contentsOf: crashInfoURL).prefix(legacySize)).write(to: crashInfoURL)
            }
        }
    }

    private func captureCrashReplay(expectCapture: Bool = true) throws -> (
        crash: Event,
        replay: (replay: SentryReplayEvent, recording: SentryReplayRecording, video: URL)?
    ) {
        let client = SentryClientInternal(options: try XCTUnwrap(SentrySDK.startOption))
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        let replayCapture = expectation(description: "Replay capture")
        replayCapture.isInverted = !expectCapture
        hub.onReplayCapture = {
            replayCapture.fulfill()
        }

        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        globalEventProcessor.reportAll(crash)

        wait(for: [replayCapture], timeout: 1)
        return (crash, hub.capturedReplayRecordingVideo.first)
    }
    
    private func replayFolder() -> String {
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
        return options.cacheDirectoryPath + "/io.sentry/\(options.parsedDsn?.getHash() ?? "")/replay"
    }

    private func currentReplayInfo() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: replayFolder() + "/replay.current"))
        return try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: data) as? [String: Any])
    }
}

#endif
