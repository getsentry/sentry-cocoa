@testable import Sentry
import XCTest

class SentrySDKTests: XCTestCase {
    
    func testStartWithConfigureOptions() {
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString
            options.debug = true
            options.logLevel = SentryLogLevel.verbose
            options.attachStacktrace = true
            options.enableAutoSessionTracking = true
        }
        
        let hub = SentrySDK.currentHub()
        XCTAssertNotNil(hub)
        XCTAssertNotNil(hub.installedIntegrations)
        XCTAssertNotNil(hub.getClient()?.options)
        
        if let options = hub.getClient()?.options {
            XCTAssertEqual(TestConstants.dsnAsString, options.dsn)
            XCTAssertEqual(SentryLogLevel.verbose, options.logLevel)
            XCTAssertEqual(true, options.attachStacktrace)
            XCTAssertEqual(true, options.enableAutoSessionTracking)
            
            assertIntegrationsInstalled(integrations: options.integrations ?? [])
        }
    }
    
    func testStartWithConfigureOptions_WrongDsn() {
        SentrySDK.start { options in
            options.dsn = "wrong"
        }
        
        let options = SentrySDK.currentHub().getClient()?.options
        
        XCTAssertEqual(false, options?.enabled)
    }
    
    func testStartWithConfigureOptions_BeforeSend() {
        var wasBeforeSendCalled = false
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString
            options.beforeSend = { event in
                wasBeforeSendCalled = true
                return event
            }
        }
        
        SentrySDK.capture(message: "")
        
        XCTAssertTrue(wasBeforeSendCalled, "beforeSend was not called.")
    }
    
    private func assertIntegrationsInstalled(integrations: [String]) {
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDK.currentHub().isIntegrationInstalled(integrationClass))
            } else {
                XCTFail("Integration \(integration) not installed.")
            }
        }
    }
}
