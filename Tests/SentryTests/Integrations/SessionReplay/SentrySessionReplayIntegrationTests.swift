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
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    private func getSut() throws -> SentrySessionReplayIntegration {
        return try XCTUnwrap(SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration)
    }
    
    private func startSDK(sessionSampleRate: Float, errorSampleRate: Float, enableSwizzling: Bool = true) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            SentrySDK.start {
                $0.dsn = "https://user@test.com/test"
                $0.experimental.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, errorSampleRate: errorSampleRate)
                $0.setIntegrations([SentrySessionReplayIntegration.self])
                $0.enableSwizzling = enableSwizzling
            }
            SentrySDK.currentHub().startSession()
        }
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
        
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)
        
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
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
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
    
}

#endif
