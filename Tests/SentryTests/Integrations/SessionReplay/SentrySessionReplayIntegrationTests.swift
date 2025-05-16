import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentrySessionReplayIntegrationTests: XCTestCase {
    
    private class TestSentryUIApplication: SentryUIApplication {
        var windowsMock: [UIWindow]? = [UIWindow()]
        var screenName: String?
        
        override var windows: [UIWindow]? {
            windowsMock
        }
        
        override func relevantViewControllersNames() -> [String]? {
            guard let screenName = screenName else { return nil }
            return [screenName]
        }
    }
    
    private class TestCrashWrapper: SentryCrashWrapper {
        let traced: Bool
        
        init(traced: Bool = true) {
            self.traced = traced
            // not calling super.init() here as we don't actually want to install crash reporter machinery
        }
        
        override func isBeingTraced() -> Bool {
            traced
        }
    }
    
    override func setUpWithError() throws {
        guard #available(iOS 16.0, tvOS 16.0, *)  else {
            throw XCTSkip("iOS version not supported")
        }
    }
    
    private var uiApplication = TestSentryUIApplication()
    
    override func setUp() {
        SentryDependencyContainer.sharedInstance().application = uiApplication
        SentryDependencyContainer.sharedInstance().reachability = TestSentryReachability()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    private func getSut() throws -> SentrySessionReplayIntegration {
        return try XCTUnwrap(SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration)
    }
    
    private func startSDK(sessionSampleRate: Float, errorSampleRate: Float, enableSwizzling: Bool = true, noIntegrations: Bool = false, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = "https://user@test.com/test"
            $0.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, onErrorSampleRate: errorSampleRate)
            $0.setIntegrations(noIntegrations ? [] : [SentrySessionReplayIntegration.self])
            $0.enableSwizzling = enableSwizzling
            $0.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
            configure?($0)
        }
        SentrySDK.currentHub().startSession()
    }
    
    func testNoInstall() {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)
        
        XCTAssertEqual(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count, 0)
        XCTAssertEqual(SentryGlobalEventProcessor.shared().processors.count, 0)
    }
    
    func testInstallFullSessionReplay() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        XCTAssertEqual(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(SentryGlobalEventProcessor.shared().processors.count, 1)
    }
    
    func testInstallNoSwizzlingNoTouchTracker() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0, enableSwizzling: false)
        guard let integration = SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        else {
            XCTFail("Could not find session replay integration")
            return
        }
        XCTAssertNil(Dynamic(integration).getTouchTracker().asObject)
    }
    
    func testInstallWithSwizzlingHasTouchTracker() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        XCTAssertNotNil(Dynamic(sut).getTouchTracker().asObject)
    }
    
    func testInstallFullSessionReplayButDontRunBecauseOfRandom() throws {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.3)
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)
        XCTAssertEqual(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(SentryGlobalEventProcessor.shared().processors.count, 1)
        let sut = try getSut()
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testInstallFullSessionReplayBecauseOfRandom() throws {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.1)
        
        startSDK(sessionSampleRate: 0.3, errorSampleRate: 0)
        
        XCTAssertEqual(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(SentryGlobalEventProcessor.shared().processors.count, 1)
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testInstallErrorReplay() {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0.1)
        
        XCTAssertEqual(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count, 1)
        XCTAssertEqual(SentryGlobalEventProcessor.shared().processors.count, 1)
    }
    
    func testWaitForNotificationWithNoWindow() throws {
        uiApplication.windowsMock = nil
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        
        XCTAssertNil(sut.sessionReplay)
        uiApplication.windowsMock = [UIWindow()]
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testPauseAndResumeForApplicationStateChange() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(Dynamic(sut.sessionReplay).isRunning.asBool ?? true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(Dynamic(sut.sessionReplay).isRunning.asBool ?? false)
    }
    
    func testStopReplayAtEndOfSession() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
        SentrySDK.currentHub().endSession()
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testStartFullSessionForError() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        
        XCTAssertFalse(Dynamic(sut.sessionReplay).isFullSession.asBool ?? true)
        SentrySDK.capture(error: NSError(domain: "", code: 1))
        XCTAssertTrue(Dynamic(sut.sessionReplay).isFullSession.asBool ?? false)
    }
    
    func testRestartReplayWithNewSession() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        XCTAssertNotNil(sut.sessionReplay)
        SentrySDK.currentHub().endSession()
        XCTAssertNil(sut.sessionReplay)
        SentrySDK.currentHub().startSession()
        XCTAssertNotNil(sut.sessionReplay)
    }
    
    func testRestartReplayWithNewSessionClosePreviousReplay() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        let sut = try getSut()
        SentrySDK.currentHub().startSession()
        XCTAssertNotNil(sut.sessionReplay)
        let oldSessionReplay = sut.sessionReplay
        XCTAssertTrue(oldSessionReplay?.isRunning ?? false)
        SentrySDK.currentHub().startSession()
        XCTAssertFalse(oldSessionReplay?.isRunning ?? true)
    }
    
    func testScreenNameFromSentryUIApplication() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut: SentrySessionReplayDelegate = try getSut() as! SentrySessionReplayDelegate
        uiApplication.screenName = "Test Screen"
        XCTAssertEqual(sut.currentScreenNameForSessionReplay(), "Test Screen")
    }
    
    func testScreenNameFromSentryScope() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        SentrySDK.currentHub().configureScope { scope in
            scope.currentScreen = "Scope Screen"
        }
        
        let sut: SentrySessionReplayDelegate = try getSut() as! SentrySessionReplayDelegate
        uiApplication.screenName = "Test Screen"
        XCTAssertEqual(sut.currentScreenNameForSessionReplay(), "Scope Screen")
    }
    
    func testSessionReplayForCrash() throws {
        try createLastSessionReplay()
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        let client = SentryClient(options: try XCTUnwrap(SentrySDK.options))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be capture")
        hub.onReplayCapture = {
            expectation.fulfill()
        }
        
        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        SentryGlobalEventProcessor.shared().reportAll(crash)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 1)
        
        let replayInfo = try XCTUnwrap(hub.capturedReplayRecordingVideo.first)
        XCTAssertEqual(replayInfo.replay.replayType, SentryReplayType.session)
        XCTAssertEqual(replayInfo.recording.segmentId, 2)
        XCTAssertEqual(replayInfo.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 5))
    }
    
    func testBufferReplayForCrash() throws {
        try createLastSessionReplay(writeSessionInfo: false)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        let client = SentryClient(options: try XCTUnwrap(SentrySDK.options))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be capture")
        hub.onReplayCapture = {
            expectation.fulfill()
        }
        
        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        SentryGlobalEventProcessor.shared().reportAll(crash)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 1)
        
        let replayInfo = try XCTUnwrap(hub.capturedReplayRecordingVideo.first)
        XCTAssertEqual(replayInfo.replay.replayType, SentryReplayType.buffer)
        XCTAssertEqual(replayInfo.recording.segmentId, 0)
        XCTAssertEqual(replayInfo.replay.replayStartTimestamp, Date(timeIntervalSinceReferenceDate: 5))
    }
    
    func testBufferReplayIgnoredBecauseSampleRateForCrash() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        let client = SentryClient(options: try XCTUnwrap(SentrySDK.options))
        let scope = Scope()
        let hub = TestHub(client: client, andScope: scope)
        SentrySDK.setCurrentHub(hub)
        let expectation = expectation(description: "Replay to be capture")
        expectation.isInverted = true
        hub.onReplayCapture = {
            expectation.fulfill()
        }
        
        try createLastSessionReplay(writeSessionInfo: false, errorSampleRate: 0)
        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true
        SentryGlobalEventProcessor.shared().reportAll(crash)
        
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 0)
    }
    
    func testPauseSessionReplayWithReacheability() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        let sut = try getSut()
        (sut as? SentryReachabilityObserver)?.connectivityChanged(false, typeDescription: "")
        XCTAssertTrue(sut.sessionReplay.isSessionPaused)
        (sut as? SentryReachabilityObserver)?.connectivityChanged(true, typeDescription: "")
        XCTAssertFalse(sut.sessionReplay.isSessionPaused)
    }
  
    func testMaskViewFromSDK() throws {
        class AnotherLabel: UILabel {
        }
            
        startSDK(sessionSampleRate: 1, errorSampleRate: 1) { options in
            options.sessionReplay.maskedViewClasses = [AnotherLabel.self]
        }
        
        let sut = try getSut()
        let redactBuilder = sut.viewPhotographer.getRedactBuild()
        XCTAssertTrue(redactBuilder.containsRedactClass(AnotherLabel.self))
    }
    
    func testIgnoreViewFromSDK() throws {
        class AnotherLabel: UILabel {
        }
            
        startSDK(sessionSampleRate: 1, errorSampleRate: 1) { options in
            options.sessionReplay.unmaskedViewClasses = [AnotherLabel.self]
        }
    
        let sut = try getSut()
        let redactBuilder = sut.viewPhotographer.getRedactBuild()
        XCTAssertTrue(redactBuilder.containsIgnoreClass(AnotherLabel.self))
    }
    
    func testStop() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
        
        SentrySDK.replay.stop()
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testStartWithNoSessionReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0, noIntegrations: true)
        var sut = SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        XCTAssertNil(sut)
        SentrySDK.replay.start()
        sut = try getSut()
        
        let sessionReplay = sut?.sessionReplay
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
        XCTAssertTrue(sessionReplay?.isFullSession ?? false)
        XCTAssertNotNil(sut?.sessionReplay)
    }
    
    func testStartWithSessionReplayRunning() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        let replayId = sessionReplay.sessionReplayId
        
        SentrySDK.replay.start()
        
        //Test whether the integration keeps the same instance of the session replay
        XCTAssertEqual(sessionReplay, sut.sessionReplay)
        //Test whether the session Id is still the same
        XCTAssertEqual(sessionReplay.sessionReplayId, replayId)
    }
    
    func testStopBecauseOfReplayRateLimit() throws {
        let rateLimiter = TestRateLimits()
        SentryDependencyContainer.sharedInstance().rateLimits = rateLimiter
        rateLimiter.rateLimits.append(.replay)
        
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
  
        let videoUrl = URL(fileURLWithPath: "video.mp4")
        let videoInfo = SentryVideoInfo(path: videoUrl, height: 1_024, width: 480, duration: 5, frameCount: 5, frameRate: 1, start: Date(), end: Date(), fileSize: 10, screens: [])
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 0)
        
        (sut as! SentrySessionReplayDelegate).sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)
        
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
        
        (sut as! SentrySessionReplayDelegate).sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testDontRestartAfterRateLimit() throws {
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
        
        (sut as! SentrySessionReplayDelegate).sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
        
        sut.start()
        
        XCTAssertFalse(sessionReplay?.isRunning ?? true)
        XCTAssertNil(sut.sessionReplay)
    }
    
    func testAlowStartForNewSessionAfterRateLimit() throws {
        let rateLimiter = TestRateLimits()
        SentryDependencyContainer.sharedInstance().rateLimits = rateLimiter
        rateLimiter.rateLimits.append(.all)
        
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = sut.sessionReplay
        sut.start()
        
        XCTAssertTrue(sessionReplay?.isRunning ?? false)
  
        let videoUrl = URL(fileURLWithPath: "video.mp4")
        let videoInfo = SentryVideoInfo(path: videoUrl, height: 1_024, width: 480, duration: 5, frameCount: 5, frameRate: 1, start: Date(), end: Date(), fileSize: 10, screens: [])
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 0)
        
        (sut as! SentrySessionReplayDelegate).sessionReplayNewSegment(replayEvent: replayEvent,
                                                                     replayRecording: SentryReplayRecording(segmentId: 0, video: videoInfo, extraEvents: []),
                                                                     videoUrl: videoUrl)
        XCTAssertNil(sut.sessionReplay)
        
        sut.start()
        XCTAssertNil(sut.sessionReplay)
        
        (sut as! SentrySessionListener).sentrySessionStarted(SentrySession(releaseName: "", distinctId: ""))
        
        sut.start()
        XCTAssertTrue(sut.sessionReplay?.isRunning ?? false)
    }
    
    func testStartWithBufferSessionReplay() throws {
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        let sessionReplay = try XCTUnwrap(sut.sessionReplay)
        
        XCTAssertFalse(sessionReplay.isFullSession)
        SentrySDK.replay.start()
        XCTAssertTrue(sessionReplay.isFullSession)
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
        SentryDependencyContainer.sharedInstance().fileManager = try SentryFileManager(options: options)
        
        if FileManager.default.fileExists(atPath: replayFolder()) {
            try FileManager.default.removeItem(atPath: replayFolder())
        }
        
        // We can't use SentrySDK.start because the dependency container dispatch queue is used for other tasks.
        // Manually starting the integration and initializing it makes the test more controlled.
        let integration = SentrySessionReplayIntegration()
        integration.install(with: options)
        
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
        SentryDependencyContainer.sharedInstance().crashWrapper = TestCrashWrapper(traced: true)
        let window = UIWindow()
        uiApplication.windowsMock = [window]
        
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        sut.showMaskPreview(1)
        
        XCTAssertEqual(window.subviews.count, 1, "Mask preview did not appear in production" )
        XCTAssertTrue(window.subviews.first is SentryMaskingPreviewView)
    }
    
    func testDontShowMaskPreviewForRelese() throws {
        SentryDependencyContainer.sharedInstance().crashWrapper = TestCrashWrapper(traced: false)
        let window = UIWindow()
        uiApplication.windowsMock = [window]
        
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()
        sut.showMaskPreview(1)
        
        XCTAssertEqual(window.subviews.count, 0, "Mask preview should not appear in production")
    }

    func testMoveCurrentReplay_whenLastFileExistsWithoutCurrent_shouldBeRemoved() throws {
        // -- Arrange --
        startSDK(sessionSampleRate: 0, errorSampleRate: 1)
        let sut = try getSut()

        let replayFolder = sut.replayDirectory()
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

        let replayFolder = sut.replayDirectory()
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
        let dynamicSut = Dynamic(sut)

        // -- Act --
        let processingQueue = try XCTUnwrap(dynamicSut.replayProcessingQueue.asObject as? SentryDispatchQueueWrapper)
        let assetWorkerQueue = try XCTUnwrap(dynamicSut.replayAssetWorkerQueue.asObject as? SentryDispatchQueueWrapper)

        // -- Assert --
        XCTAssertEqual(assetWorkerQueue.queue.label, "io.sentry.session-replay.asset-worker")
        XCTAssertEqual(assetWorkerQueue.queue.qos.qosClass, .background)

        XCTAssertEqual(processingQueue.queue.label, "io.sentry.session-replay.processing")
        XCTAssertEqual(processingQueue.queue.qos.qosClass, .background)

        // The actual priorities are not relevant, we just need to check that the processing queue has a lower priority
        // than the asset worker queue and that both are lower than the default priority.
        XCTAssertLessThan(processingQueue.queue.qos.relativePriority, 0)
        XCTAssertLessThan(processingQueue.queue.qos.relativePriority, assetWorkerQueue.queue.qos.relativePriority)
    }

    private func createLastSessionReplay(writeSessionInfo: Bool = true, errorSampleRate: Double = 1) throws {
        let replayFolder = replayFolder()
        let jsonPath = replayFolder + "/replay.current"
        var sessionFolder = UUID().uuidString
        let info: [String: Any] = ["replayId": SentryId().sentryIdString,
                                    "path": sessionFolder,
                                    "errorSampleRate": errorSampleRate]
        let data = SentrySerialization.data(withJSONObject: info)
        
        try FileManager.default.createDirectory(atPath: replayFolder, withIntermediateDirectories: true)
        
        try data?.write(to: URL(fileURLWithPath: jsonPath))
        
        sessionFolder = "\(replayFolder)/\(sessionFolder)"
        try FileManager.default.createDirectory(atPath: sessionFolder, withIntermediateDirectories: true)
                       
        for i in 5...9 {
            let image = UIImage.add.jpegData(compressionQuality: 1)
            try image?.write(to: URL(fileURLWithPath: "\(sessionFolder)/\(i).png") )
        }
        
        if writeSessionInfo {
            sentrySessionReplaySync_start("\(sessionFolder)/crashInfo")
            sentrySessionReplaySync_updateInfo(1, Double(4))
            sentrySessionReplaySync_writeInfo()
        }
    }
    
    private func replayFolder() -> String {
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
        return options.cacheDirectoryPath + "/io.sentry/\(options.parsedDsn?.getHash() ?? "")/replay"
    }
}

#endif
