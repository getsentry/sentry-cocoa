@testable import Sentry
import XCTest

class SentrySDKTests: XCTestCase {
    
    private class Fixture {
    
        let event: Event
        let scope: Scope
        let client: TestClient
        let hub: SentryHub
        let error: Error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let userFeedback: UserFeedack
        
        init() {
            event = Event()
            event.message = SentryMessage(formatted: "message")
            
            scope = Scope()
            scope.setTag(value: "value", key: "key")
            
            client = TestClient(options: Options())!
            hub = SentryHub(client: client, andScope: scope)
            
            userFeedback = UserFeedack(eventId: SentryId())
            userFeedback.comments = "Again really?"
            userFeedback.email = "tim@apple.com"
            userFeedback.name = "Tim Apple"
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
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
        
        let event = fixture.event
        SentrySDK.captureCrash(event)
    
        XCTAssertEqual(1, hub.sentCrashEvents.count)
        XCTAssertEqual(event.message, hub.sentCrashEvents.first?.message)
        XCTAssertEqual(event.eventId, hub.sentCrashEvents.first?.eventId)
    }
    
    func testCaptureEvent() {
        givenSdkWithHub()
        
        SentrySDK.capture(event: fixture.event)
        
        assertEventCaptured(expectedScope: fixture.scope)
    }

    func testCaptureEventWithScope() {
        givenSdkWithHub()
        
        let scope = Scope()
        SentrySDK.capture(event: fixture.event, scope: scope)
    
        assertEventCaptured(expectedScope: scope)
    }
    
    func testCaptureError() {
        givenSdkWithHub()
        
        SentrySDK.capture(error: fixture.error)
        
        assertErrorCaptured(expectedScope: fixture.scope)
    }
    
    func testCaptureErrorWithScope() {
        givenSdkWithHub()
        
        let scope = Scope()
        SentrySDK.capture(error: fixture.error, scope: scope)
        
        assertErrorCaptured(expectedScope: scope)
    }
    
    func testCaptureException() {
        givenSdkWithHub()
        
        SentrySDK.capture(exception: fixture.exception)
        
        assertExceptionCaptured(expectedScope: fixture.scope)
    }
    
    func testCaptureExceptionWithScope() {
        givenSdkWithHub()
        
        let scope = Scope()
        SentrySDK.capture(exception: fixture.exception, scope: scope)
        
        assertExceptionCaptured(expectedScope: scope)
    }
    
    func testCaptureUserFeedback() {
        givenSdkWithHub()
        
        SentrySDK.capture(userFeedback: fixture.userFeedback)
        let client = fixture.client
        XCTAssertEqual(1, client.capturedUserFeedback.count)
        if let actual = client.capturedUserFeedback.first {
            let expected = fixture.userFeedback
            XCTAssertEqual(expected.eventId, actual.eventId)
            XCTAssertEqual(expected.name, actual.name)
            XCTAssertEqual(expected.email, actual.email)
            XCTAssertEqual(expected.comments, actual.comments)
        }
    }
    
    private func givenSdkWithHub() {
        SentrySDK.setCurrentHub(fixture.hub)
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
    
    private func assertEventCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureEventWithScopeArguments.count)
        let actualEvent = client.captureEventWithScopeArguments.first?.first
        let actualScope = client.captureEventWithScopeArguments.first?.second
        XCTAssertEqual(fixture.event, actualEvent)
        XCTAssertEqual(expectedScope, actualScope)
    }
    
    private func assertErrorCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeArguments.count)
        let actualError = client.captureErrorWithScopeArguments.first?.first
        let actualScope = client.captureErrorWithScopeArguments.first?.second
        XCTAssertEqual(fixture.error.localizedDescription, actualError?.localizedDescription)
        XCTAssertEqual(expectedScope, actualScope)
    }
    
    private func assertExceptionCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeArguments.count)
        let actualException = client.captureExceptionWithScopeArguments.first?.first
        let actualScope = client.captureExceptionWithScopeArguments.first?.second
        XCTAssertEqual(fixture.exception, actualException)
        XCTAssertEqual(expectedScope, actualScope)
    }
}
