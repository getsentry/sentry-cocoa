@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryAutoSessionTrackingIntegrationTests: XCTestCase {
    
    override func tearDown() {
        clearTestState()
    }

    func test_AutoSessionTracking_Disabled() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let options = Options()
        options.enableAutoSessionTracking = false
        
        let sut = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        
        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryAutoSessionTrackingIntegration because enableAutoSessionTracking is disabled.")
        }
        XCTAssertEqual(logMessages.count, 1)
    }
    
    func test_AutoSessionTracking_DisabledOnSystemExtension() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let options = Options()
        options.enableAutoSessionTracking = true
        
        let processInfoWrapper = MockSentryProcessInfo()
        processInfoWrapper.overrides.processDirectoryPath = "randomPath/myApp.systemextension"
        SentryDependencyContainer.sharedInstance().processInfoWrapper = processInfoWrapper
        
        let sut = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        
        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryAutoSessionTrackingIntegration because it is not supported on system extensions.")
        }
        XCTAssertEqual(logMessages.count, 1)
    }
    
    func test_AutoSessionTracking_Enabled() {
        let options = Options()
        options.enableAutoSessionTracking = true
        
        let sut = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }
        
        XCTAssertNotNil(sut)
    }
}
