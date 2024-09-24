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
    
    private func startSDK(sessionSampleRate: Float, errorSampleRate: Float, enableSwizzling: Bool = true, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = "https://user@test.com/test"
            $0.experimental.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, onErrorSampleRate: errorSampleRate)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
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
        let sut: SentrySessionReplayDelegate = try getSut()
        uiApplication.screenName = "Test Screen"
        XCTAssertEqual(sut.currentScreenNameForSessionReplay(), "Test Screen")
    }
    
    func testScreenNameFromSentryScope() throws {
        startSDK(sessionSampleRate: 1, errorSampleRate: 1)
        
        SentrySDK.currentHub().configureScope { scope in
            scope.currentScreen = "Scope Screen"
        }
        
        let sut: SentrySessionReplayDelegate = try getSut()
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
        crash.isCrashEvent = true
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
        crash.isCrashEvent = true
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
        crash.isCrashEvent = true
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
            options.experimental.sessionReplay.redactViewClasses = [AnotherLabel.self]
        }
        
        let sut = try getSut()
        let redactBuilder = sut.viewPhotographer.getRedactBuild()
        XCTAssertTrue(redactBuilder.containsRedactClass(AnotherLabel.self))
    }
    
    func testIgnoreViewFromSDK() throws {
        class AnotherLabel: UILabel {
        }
            
        startSDK(sessionSampleRate: 1, errorSampleRate: 1) { options in
            options.experimental.sessionReplay.ignoreViewClasses = [AnotherLabel.self]
        }
    
        let sut = try getSut()
        let redactBuilder = sut.viewPhotographer.getRedactBuild()
        XCTAssertTrue(redactBuilder.containsIgnoreClass(AnotherLabel.self))
    }
    
    func createLastSessionReplay(writeSessionInfo: Bool = true, errorSampleRate: Double = 1) throws {
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory.path
        
        let replayFolder = options.cacheDirectoryPath + "/io.sentry/\(options.parsedDsn?.getHash() ?? "")/replay"
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
}

#endif
