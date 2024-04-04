import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentrySessionReplayIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        guard #available(iOS 16.0, tvOS 16.0, *)  else {
            throw XCTSkip("iOS version not supported")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func startSDK(sessionSampleRate: Float, errorSampleRate: Float) {
        if #available(iOS 16.0, tvOS 16.0, *) {
            SentrySDK.start {
                $0.experimental.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: sessionSampleRate, errorSampleRate: errorSampleRate)
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
}

#endif
