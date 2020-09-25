@testable import Sentry
import XCTest

class SentrySDKTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        
        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations.first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }
    }
    
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
        
        let options = hub.getClient()?.options
        XCTAssertNotNil(options)
        XCTAssertEqual(TestConstants.dsnAsString, options?.dsn)
        XCTAssertEqual(SentryLogLevel.verbose, options?.logLevel)
        XCTAssertEqual(true, options?.attachStacktrace)
        XCTAssertEqual(true, options?.enableAutoSessionTracking)
        
        assertIntegrationsInstalled(integrations: options?.integrations ?? [])
    }
    
    func testStartWithConfigureOptions_NoDsn() throws {
        SentrySDK.start { options in
            options.debug = true
        }
        
        let options = SentrySDK.currentHub().getClient()?.options
        XCTAssertNotNil(options, "Options should not be nil")
        XCTAssertNil(options?.parsedDsn)
        XCTAssertEqual(true, options?.debug)
    }
    
    func testStartWithConfigureOptions_WrongDsn() throws {
        SentrySDK.start { options in
            options.dsn = "wrong"
        }
        
        let options = SentrySDK.currentHub().getClient()?.options
        XCTAssertNotNil(options, "Options should not be nil")
        XCTAssertNil(options?.parsedDsn)
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
    
    func testSetLogLevel_StartWithOptionsDict() {
        SentrySDK.start(options: [
            "dsn": TestConstants.dsn,
            "debug": true,
            "logLevel": "verbose"
        ])
        
        XCTAssertEqual(SentryLogLevel.verbose, SentrySDK.logLevel)
    }
    
    func testSetLogLevel_StartWithOptionsObject() {
        let options = Options()
        options.dsn = TestConstants.dsnAsString
        options.logLevel = SentryLogLevel.debug
        
        SentrySDK.start(options: options)
        
        XCTAssertEqual(options.logLevel, SentrySDK.logLevel)
    }
    
    func testSetLogLevel_StartWithConfigureOptions() {
        let logLevel = SentryLogLevel.verbose
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString
            options.logLevel = logLevel
        }
        
        XCTAssertEqual(logLevel, SentrySDK.logLevel)
    }
    
    func testCrashedLastRun() {
        XCTAssertEqual(SentryCrash.sharedInstance().crashedLastLaunch, SentrySDK.crashedLastRun) 
    }
    
    func testCaptureCrashEvent() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let event = Event()
        event.message = "crash"
        SentrySDK.captureCrash(event)
    
        XCTAssertEqual(1, hub.sentCrashEvents.count)
        XCTAssertEqual(event.message, hub.sentCrashEvents.first?.message)
        XCTAssertEqual(event.eventId, hub.sentCrashEvents.first?.eventId)
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
