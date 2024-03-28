import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

@available(iOS 16.0, tvOS 16.0, *)
class SentrySessionReplayIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        if #unavailable(iOS 16.0, tvOS 16.0) {
            throw XCTSkip("iOS version not supported")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testNoInstall() {
        SentrySDK.start {
            $0.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: 0, errorSampleRate: 0)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
        }
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 0
        expect(SentryGlobalEventProcessor.shared().processors.count) == 0
    }
    
    func testInstallFullSessionReplay() {
        SentrySDK.start {
            $0.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 0)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
        }
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
    }
    
    func testNoInstallFullSessionReplayBecauseOfRandom() {
        
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.3)
        
        SentrySDK.start {
            $0.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: 0.2, errorSampleRate: 0)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
        }
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 0
        expect(SentryGlobalEventProcessor.shared().processors.count) == 0
    }
    
    func testInstallFullSessionReplayBecauseOfRandom() {
        
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.1)
        
        SentrySDK.start {
            $0.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: 0.2, errorSampleRate: 0)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
        }
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
    }
    
    func testInstallErrorReplay() {
        SentrySDK.start {
            $0.sessionReplayOptions = SentryReplayOptions(sessionSampleRate: 0, errorSampleRate: 0.1)
            $0.setIntegrations([SentrySessionReplayIntegration.self])
        }
        
        expect(SentrySDK.currentHub().trimmedInstalledIntegrationNames().count) == 1
        expect(SentryGlobalEventProcessor.shared().processors.count) == 1
    }
}

#endif
