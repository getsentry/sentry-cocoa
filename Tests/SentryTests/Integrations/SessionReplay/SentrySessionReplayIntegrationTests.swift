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
    
    func startSDK(sessionSampleRate: Float, errorSampleRate: Float) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            SentrySDK.start {
                $0.experimental.sessionReplay = SentryReplayOptions(sessionSampleRate: sessionSampleRate, errorSampleRate: errorSampleRate)
                $0.setIntegrations([SentrySessionReplayIntegration.self])
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
}

#endif
