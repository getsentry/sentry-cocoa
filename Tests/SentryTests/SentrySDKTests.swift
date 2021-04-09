@testable import Sentry
import XCTest

class SentrySDKTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySDKTests")
    private static let dsn = TestConstants.dsn(username: "SentrySDKTests")
    
    private class Fixture {
    
        let options: Options
        let event: Event
        let scope: Scope
        let client: TestClient
        let hub: SentryHub
        let error: Error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let userFeedback: UserFeedback
        let currentDate = TestCurrentDateProvider()
        
        let scopeBlock: (Scope) -> Void = { scope in
            scope.setTag(value: "tag", key: "tag")
        }
        
        var scopeWithBlockApplied: Scope {
            get {
                let scope = self.scope
                scopeBlock(scope)
                return scope
            }
        }
        
        let message = "message"
        
        init() {
            CurrentDate.setCurrentDateProvider(currentDate)
            
            event = Event()
            event.message = SentryMessage(formatted: message)
            
            scope = Scope()
            scope.setTag(value: "value", key: "key")
            
            options = Options()
            options.dsn = SentrySDKTests.dsnAsString
            options.releaseName = "1.0.0"
            client = TestClient(options: options)!
            hub = SentryHub(client: client, andScope: scope)
            
            userFeedback = UserFeedback(eventId: SentryId())
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
        
        givenSdkWithHubButNoClient()
        
        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations.first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }
    }
    
    func testStartWithConfigureOptions() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.debug = true
            options.diagnosticLevel = SentryLevel.debug
            options.attachStacktrace = true
        }
        
        let hub = SentrySDK.currentHub()
        XCTAssertNotNil(hub)
        XCTAssertNotNil(hub.installedIntegrations)
        XCTAssertNotNil(hub.getClient()?.options)
        
        let options = hub.getClient()?.options
        XCTAssertNotNil(options)
        XCTAssertEqual(SentrySDKTests.dsnAsString, options?.dsn)
        XCTAssertEqual(SentryLevel.debug, options?.diagnosticLevel)
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
        XCTAssertTrue(options?.enabled ?? false)
        XCTAssertEqual(true, options?.debug)
    }
    
    func testStartWithConfigureOptions_WrongDsn() throws {
        SentrySDK.start { options in
            options.dsn = "wrong"
        }
        
        let options = SentrySDK.currentHub().getClient()?.options
        XCTAssertNotNil(options, "Options should not be nil")
        XCTAssertTrue(options?.enabled ?? false)
        XCTAssertNil(options?.parsedDsn)
    }
    
    func testStartWithConfigureOptions_BeforeSend() {
        var wasBeforeSendCalled = false
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.beforeSend = { event in
                wasBeforeSendCalled = true
                return event
            }
        }
        
        SentrySDK.capture(message: "")
        
        XCTAssertTrue(wasBeforeSendCalled, "beforeSend was not called.")
    }

    func testStartWithConfigureOptions_UrlSessionDelegate() {
        let urlSessionDelegateSpy = UrlSessionDelegateSpy()

        let predicate = NSPredicate { (_, _) -> Bool in
            urlSessionDelegateSpy.delegateCalled
        }
        let expectation = self.expectation(for: predicate, evaluatedWith: nil)
        expectation.expectationDescription = "urlSession_didReceive_completionHandler will be called on UrlSessionDelegateSpy"

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.urlSessionDelegate = urlSessionDelegateSpy
        }

        SentrySDK.capture(message: "")

        wait(for: [expectation], timeout: 10)
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
    
    func testSpan() {
        givenSdkWithHub()
        
        let span = SentrySDK.startTransaction(name: "Some Transaction", operation: "Operations", bindToScope: true)
        let newSpan = SentrySDK.span
        
        XCTAssert(span === newSpan)
    }
    
    func testCaptureEventWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()
        
        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertEventCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureEventWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()
        
        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertHubScopeNotChanged()
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
    
    func testCaptureErrorWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()
        
        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)
        
        assertErrorCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureErrorWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()
        
        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
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
    
    func testCaptureExceptionWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()
        
        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)
        
        assertExceptionCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureExceptionWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()
        
        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
    }
    
    func testCaptureMessageWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()
        
        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)
        
        assertMessageCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureMessageWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()
        
        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
    }
    
    func testCaptureEnvelope() {
        givenSdkWithHub()
        
        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.capture(envelope)
        
        XCTAssertEqual(1, fixture.client.capturedEnvelopes.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.capturedEnvelopes.first?.header.eventId)
    }
    
    func testStoreEnvelope() {
        givenSdkWithHub()
        
        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.store(envelope)
        
        XCTAssertEqual(1, fixture.client.storedEnvelopes.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.storedEnvelopes.first?.header.eventId)
    }
    
    func testStoreEnvelope_WhenNoClient_NoCrash() {
        SentrySDK.store(SentryEnvelope(event: TestData.event))
        
        XCTAssertEqual(0, fixture.client.storedEnvelopes.count)
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
    
    func testSetUser_SetsUserToScopeOfHub() {
        givenSdkWithHub()
        
        let user = TestData.user
        SentrySDK.setUser(user)
        
        let actualScope = SentrySDK.currentHub().scope
        let event = actualScope.apply(to: fixture.event, maxBreadcrumb: 10)
        XCTAssertEqual(event?.user, user)
    }
    
    func testPerformanceOfConfigureScope() {
        func buildCrumb(_ i: Int) -> Breadcrumb {
            let crumb = Breadcrumb()
            crumb.message = String(repeating: String(i), count: 100)
            crumb.data = ["some": String(repeating: String(i), count: 1_000)]
            crumb.category = String(i)
            return crumb
        }
        
        SentrySDK.start(options: ["dsn": SentrySDKTests.dsnAsString])
        
        SentrySDK.configureScope { scope in
            let user = User()
            user.email = "someone@gmail.com"
            scope.setUser(user)
        }
        
        for i in 0...100 {
            SentrySDK.configureScope { scope in
                scope.add(buildCrumb(i))
            }
        }
        
        self.measure {
            for i in 0...10 {
                SentrySDK.configureScope { scope in
                    scope.add(buildCrumb(i))
                }
            }
        }
    }
    
    func testInstallIntegrations() {
        let options = Options()
        options.dsn = "mine"
        options.integrations = ["SentryTestIntegration", "SentryTestIntegration", "IDontExist"]
        
        SentrySDK.start(options: options)
        
        assertIntegrationsInstalled(integrations: ["SentryTestIntegration"])
        let integration = SentrySDK.currentHub().installedIntegrations.firstObject
        XCTAssertTrue(integration is SentryTestIntegration)
        if let testIntegration = integration as? SentryTestIntegration {
            XCTAssertEqual(options.dsn, testIntegration.options.dsn)
            XCTAssertEqual(options.integrations, testIntegration.options.integrations)
        }
    }
    
    func testInstallIntegrations_NoIntegrations() {
        SentrySDK.start { options in
            options.integrations = []
        }
        
        assertIntegrationsInstalled(integrations: [])
    }
    
    @available(tvOS 13.0, *)
    @available(OSX 10.15, *)
    @available(iOS 13.0, *)
    func testMemoryFootprintOfAddingBreadcrumbs() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.debug = true
            options.diagnosticLevel = SentryLevel.debug
            options.attachStacktrace = true
        }
        
        self.measure(metrics: [XCTMemoryMetric()]) {
            for i in 0...1_000 {
                let crumb = TestData.crumb
                crumb.message = "\(i)"
                SentrySDK.addBreadcrumb(crumb: crumb)
            }
        }
    }
    
    func testStartSession() {
        givenSdkWithHub()
        
        SentrySDK.startSession()
        
        XCTAssertEqual(1, fixture.client.sessions.count)
        
        let actual = fixture.client.sessions.first
        let expected = SentrySession(releaseName: fixture.options.releaseName ?? "")
        
        XCTAssertEqual(expected.flagInit, actual?.flagInit)
        XCTAssertEqual(expected.errors, actual?.errors)
        XCTAssertEqual(expected.sequence, actual?.sequence)
        XCTAssertEqual(expected.releaseName, actual?.releaseName)
        XCTAssertEqual(fixture.currentDate.date(), actual?.started)
        XCTAssertEqual(SentrySessionStatus.ok, actual?.status)
        XCTAssertNil(actual?.timestamp)
        XCTAssertNil(actual?.duration)
    }
    
    func testEndSession() {
        givenSdkWithHub()
        
        SentrySDK.startSession()
        advanceTime(bySeconds: 1)
        SentrySDK.endSession()
        
        XCTAssertEqual(2, fixture.client.sessions.count)
        
        let actual = fixture.client.sessions[1]
        
        XCTAssertNil(actual.flagInit)
        XCTAssertEqual(0, actual.errors)
        XCTAssertEqual(2, actual.sequence)
        XCTAssertEqual(SentrySessionStatus.exited, actual.status)
        XCTAssertEqual(fixture.options.releaseName ?? "", actual.releaseName)
        XCTAssertEqual(1, actual.duration)
        XCTAssertEqual(fixture.currentDate.date(), actual.timestamp)
    }
    
    private func givenSdkWithHub() {
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    private func givenSdkWithHubButNoClient() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
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
        XCTAssertEqual(fixture.event, client.captureEventWithScopeArguments.first?.event)
        XCTAssertEqual(expectedScope, client.captureEventWithScopeArguments.first?.scope)
    }
    
    private func assertErrorCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeArguments.count)
        XCTAssertEqual(fixture.error.localizedDescription, client.captureErrorWithScopeArguments.first?.error.localizedDescription)
        XCTAssertEqual(expectedScope, client.captureErrorWithScopeArguments.first?.scope)
    }
    
    private func assertExceptionCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeArguments.count)
        XCTAssertEqual(fixture.exception, client.captureExceptionWithScopeArguments.first?.exception)
        XCTAssertEqual(expectedScope, client.captureExceptionWithScopeArguments.first?.scope)
    }
    
    private func assertMessageCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureMessageWithScopeArguments.count)
        XCTAssertEqual(fixture.message, client.captureMessageWithScopeArguments.first?.message)
        XCTAssertEqual(expectedScope, client.captureMessageWithScopeArguments.first?.scope)
    }
    
    private func assertHubScopeNotChanged() {
        let hubScope = SentrySDK.currentHub().scope
        XCTAssertEqual(fixture.scope, hubScope)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: fixture.currentDate.date().addingTimeInterval(bySeconds))
    }
}
