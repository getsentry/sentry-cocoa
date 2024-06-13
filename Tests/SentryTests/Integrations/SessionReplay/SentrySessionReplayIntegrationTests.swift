import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentrySessionReplayIntegrationTests: XCTestCase {
    
    private class TestSentryUIApplication: SentryUIApplication {
        var windowsMock: [UIWindow]? = [UIWindow()]
        override var windows: [UIWindow]? {
            windowsMock
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
    
    func startSDK(sessionSampleRate: Float, errorSampleRate: Float, enableSwizzling: Bool = true) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            SentrySDK.start {
                $0.experimental.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, errorSampleRate: errorSampleRate)
                $0.setIntegrations([SentrySessionReplayIntegration.self])
                $0.enableSwizzling = enableSwizzling
            }
        }
    }
    
    func testNoInstall() {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0)
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 0
        expect(SentryGlobalEventProcessor.shared().processors.count) == 0
    }
    
    func testInstallFullSessionReplay() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
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
    
    func testInstallWithSwizzlingHasTouchTracker() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        guard let integration = SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        else {
            XCTFail("Could not find session replay integration")
            return
        }
        XCTAssertNotNil(Dynamic(integration).getTouchTracker().asObject)
    }
    
    func testNoInstallFullSessionReplayBecauseOfRandom() {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.3)
        
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 0
        expect(SentryGlobalEventProcessor.shared().processors.count) == 0
    }
    
    func testInstallFullSessionReplayBecauseOfRandom() {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.1)
        
        startSDK(sessionSampleRate: 0.2, errorSampleRate: 0)
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
    }
    
    func testInstallErrorReplay() {
        startSDK(sessionSampleRate: 0, errorSampleRate: 0.1)
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
    }
    
    func testWaitForNotificationWithNoWindow() {
        uiApplication.windowsMock = nil
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        guard let sut = SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration else {
            fail("Did not installed replay integration")
            return
        }
        
        expect(Dynamic(sut).sessionReplay.asObject) == nil
        uiApplication.windowsMock = [UIWindow()]
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
        expect(Dynamic(sut).sessionReplay.asObject) != nil
    }
    
    func testPauseAndResumeForApplicationStateChange() {
        startSDK(sessionSampleRate: 1, errorSampleRate: 0)
        
        guard let sut = SentrySDK.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration else {
            XCTFail("Did not find Session Replay Integration")
            return
        }
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(Dynamic(sut.sessionReplay).isRunning.asBool ?? true)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(Dynamic(sut.sessionReplay).isRunning.asBool ?? false)
    }
}

#endif
