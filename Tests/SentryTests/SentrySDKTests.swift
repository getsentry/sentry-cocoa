@testable import Sentry
import XCTest

class SentrySDKTests: SentryBaseUnitTest {
    
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
            hub = SentryHub(client: client, andScope: scope, andCrashWrapper: TestSentryCrashWrapper.sharedInstance(), andCurrentDateProvider: currentDate)
            
            userFeedback = UserFeedback(eventId: SentryId())
            userFeedback.comments = "Again really?"
            userFeedback.email = "tim@apple.com"
            userFeedback.name = "Tim Apple"
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        
        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations.first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }
    }
    
    // Repro for: https://github.com/getsentry/sentry-cocoa/issues/1325
    func testStartWithZeroMaxBreadcrumbsOptionsDoesNotCrash() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.maxBreadcrumbs = 0
        }

        SentrySDK.addBreadcrumb(Breadcrumb(level: SentryLevel.warning, category: "test"))
        let breadcrumbs = Dynamic(SentrySDK.currentHub().scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(0, breadcrumbs?.count)
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

        assertIntegrationsInstalled(integrations: [
            "SentryCrashIntegration",
            "SentryAutoBreadcrumbTrackingIntegration",
            "SentryAutoSessionTrackingIntegration",
            "SentryNetworkTrackingIntegration"
        ])
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
        SentrySDK.capture(event: fixture.event)
        
        assertEventCaptured(expectedScope: fixture.scope)
    }

    func testCaptureEventWithScope() {
        let scope = Scope()
        SentrySDK.capture(event: fixture.event, scope: scope)

        assertEventCaptured(expectedScope: scope)
    }

    func testCaptureEventWithScopeBlock_ScopePassedToHub() {
        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)

        assertEventCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureEventWithScopeBlock_CreatesNewScope() {
        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }
    
    func testCaptureError() {
        SentrySDK.capture(error: fixture.error)
        
        assertErrorCaptured(expectedScope: fixture.scope)
    }
    
    func testCaptureErrorWithScope() {
        let scope = Scope()
        SentrySDK.capture(error: fixture.error, scope: scope)
        
        assertErrorCaptured(expectedScope: scope)
    }
    
    func testCaptureErrorWithScopeBlock_ScopePassedToHub() {
        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)
        
        assertErrorCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureErrorWithScopeBlock_CreatesNewScope() {
        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
    }
    
    func testCaptureException() {
        SentrySDK.capture(exception: fixture.exception)
        
        assertExceptionCaptured(expectedScope: fixture.scope)
    }
    
    func testCaptureExceptionWithScope() {
        let scope = Scope()
        SentrySDK.capture(exception: fixture.exception, scope: scope)
        
        assertExceptionCaptured(expectedScope: scope)
    }
    
    func testCaptureExceptionWithScopeBlock_ScopePassedToHub() {
        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)
        
        assertExceptionCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureExceptionWithScopeBlock_CreatesNewScope() {
        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
    }
    
    func testCaptureMessageWithScopeBlock_ScopePassedToHub() {
        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)
        
        assertMessageCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }
    
    func testCaptureMessageWithScopeBlock_CreatesNewScope() {
        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)
        
        assertHubScopeNotChanged()
    }
    
    func testCaptureEnvelope() {
        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.capture(envelope)
        
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.captureEnvelopeInvocations.first?.header.eventId)
    }
    
    func testStoreEnvelope() {
        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.store(envelope)
        
        XCTAssertEqual(1, fixture.client.storedEnvelopeInvocations.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.storedEnvelopeInvocations.first?.header.eventId)
    }
    
    func testStoreEnvelope_WhenNoClient_NoCrash() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
        SentrySDK.store(SentryEnvelope(event: TestData.event))
        
        XCTAssertEqual(0, fixture.client.storedEnvelopeInvocations.count)
    }
    
    func testCaptureUserFeedback() {
        SentrySDK.capture(userFeedback: fixture.userFeedback)
        let client = fixture.client
        XCTAssertEqual(1, client.captureUserFeedbackInvocations.count)
        if let actual = client.captureUserFeedbackInvocations.first {
            let expected = fixture.userFeedback
            XCTAssertEqual(expected.eventId, actual.eventId)
            XCTAssertEqual(expected.name, actual.name)
            XCTAssertEqual(expected.email, actual.email)
            XCTAssertEqual(expected.comments, actual.comments)
        }
    }
    
    func testSetUser_SetsUserToScopeOfHub() {
        let user = TestData.user
        SentrySDK.setUser(user)
        
        let actualScope = SentrySDK.currentHub().scope
        let event = actualScope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        XCTAssertEqual(event?.user, user)
    }
    
    func testStartTransaction() {
        let span = SentrySDK.startTransaction(name: "Some Transaction", operation: "Operations", bindToScope: true)
        let newSpan = SentrySDK.span
        
        XCTAssert(span === newSpan)
    }
    
    func testInstallIntegrations() {
        let options = Options()
        options.dsn = "mine"
        options.integrations = ["SentryTestIntegration", "SentryTestIntegration", "IDontExist"]
        
        SentrySDK.start(options: options)
        
        assertIntegrationsInstalled(integrations: ["SentryTestIntegration"])
        let integration = SentrySDK.currentHub().installedIntegrations.first
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
    
    func testStartSession() {
        SentrySDK.startSession()
        
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
        
        let actual = fixture.client.captureSessionInvocations.first
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
    
    func testEndSession() throws {
        SentrySDK.startSession()
        advanceTime(bySeconds: 1)
        SentrySDK.endSession()
        
        XCTAssertEqual(2, fixture.client.captureSessionInvocations.count)
        
        let actual = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.last)
        
        XCTAssertNil(actual.flagInit)
        XCTAssertEqual(0, actual.errors)
        XCTAssertEqual(2, actual.sequence)
        XCTAssertEqual(SentrySessionStatus.exited, actual.status)
        XCTAssertEqual(fixture.options.releaseName ?? "", actual.releaseName)
        XCTAssertEqual(1, actual.duration)
        XCTAssertEqual(fixture.currentDate.date(), actual.timestamp)
    }
    
    func testGlobalOptions() {
        SentrySDK.setCurrentHub(fixture.hub)
        XCTAssertEqual(SentrySDK.options, fixture.options)
    }
    
    func testSetAppStartMeasurement_CallsPrivateSDKCallback() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)

        let exp = expectation(description: "Callback invoked with app start measurement")
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = { measurement in
            guard measurement != nil else {
                return
            }
            XCTAssertEqual(appStartMeasurement, measurement)
            exp.fulfill()
        }
        
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        waitForExpectations(timeout: 1)
    }
    
    func testSetAppStartMeasurement_NoCallback_CallbackNotCalled() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)
        
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        XCTAssertEqual(SentrySDK.getAppStartMeasurement(), appStartMeasurement)
    }
    
    func testSDKStartInvocations() {
        XCTAssertEqual(0, SentrySDK.startInvocations)
        
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        
        XCTAssertEqual(1, SentrySDK.startInvocations)
    }
    
    func testIsEnabled() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))

        XCTAssertFalse(SentrySDK.isEnabled)
        
        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)
        
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        XCTAssertTrue(SentrySDK.isEnabled)
        
        SentrySDK.close()
        XCTAssertFalse(SentrySDK.isEnabled)
        
        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)
        
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        XCTAssertTrue(SentrySDK.isEnabled)
    }
    
    func testClose_ResetsDependencyContainer() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        
        let first = SentryDependencyContainer.sharedInstance()
        
        SentrySDK.close()
        
        let second = SentryDependencyContainer.sharedInstance()
        
        XCTAssertNotEqual(first, second)
    }
    
    func testClose_ClearsIntegrations() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        
        let hub = SentrySDK.currentHub()
        SentrySDK.close()
        XCTAssertEqual(0, hub.installedIntegrations.count)
        assertIntegrationsInstalled(integrations: [])
    }
    
    func testFlush_CallsFlushCorrectlyOnTransport() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
        }
        
        let transport = TestTransport()
        let client = SentryClient(options: fixture.options)
        Dynamic(client).transportAdapter = TestTransportAdapter(transport: transport, options: fixture.options)
        SentrySDK.currentHub().bindClient(client)
        
        let flushTimeout = 10.0
        SentrySDK.flush(timeout: flushTimeout)
        
        XCTAssertEqual(flushTimeout, transport.flushInvocations.first)
    }
    
    func testSetpAppStartMeasurementConcurrently_() {
        func setAppStartMeasurement(_ queue: DispatchQueue, _ i: Int) {
            group.enter()
            queue.async {
                let timestamp = self.fixture.currentDate.date().addingTimeInterval( TimeInterval(i))
                let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm, appStartTimestamp: timestamp)
                SentrySDK.setAppStartMeasurement(appStartMeasurement)
                group.leave()
            }
        }
        
        func createQueue() -> DispatchQueue {
            return DispatchQueue(label: "SentrySDKTests", qos: .userInteractive, attributes: [.initiallyInactive])
        }
        
        let queue1 = createQueue()
        let queue2 = createQueue()
        let group = DispatchGroup()
        
        let amount = 100
        
        for i in 0...amount {
            setAppStartMeasurement(queue1, i)
            setAppStartMeasurement(queue2, i)
        }
        
        queue1.activate()
        queue2.activate()
        group.waitWithTimeout(timeout: 100)
        
        let timestamp = self.fixture.currentDate.date().addingTimeInterval(TimeInterval(amount))
        XCTAssertEqual(timestamp, SentrySDK.getAppStartMeasurement()?.appStartTimestamp)
    }

    func testMovesBreadcrumbsToPreviousBreadcrumbs() {
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try! TestFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
        let observer = SentryOutOfMemoryScopeObserver(maxBreadcrumbs: 10, fileManager: fileManager)
        let serializedBreadcrumb = TestData.crumb.serialize()

        for _ in 0..<3 {
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }

        SentrySDK.start(options: options)

        let result = fileManager.readPreviousBreadcrumbs()
        XCTAssertEqual(result.count, 3)
    }
}

private extension SentrySDKTests {
    func assertIntegrationsInstalled(integrations: [String]) {
        XCTAssertEqual(integrations.count, SentrySDK.currentHub().installedIntegrations.count)
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDK.currentHub().isIntegrationInstalled(integrationClass), "\(integration) not installed")
            } else {
                XCTFail("Integration \(integration) not installed.")
            }
        }
    }
    
    func assertEventCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
        XCTAssertEqual(fixture.event, client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(expectedScope, client.captureEventWithScopeInvocations.first?.scope)
    }
    
    func assertErrorCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeInvocations.count)
        XCTAssertEqual(fixture.error.localizedDescription, client.captureErrorWithScopeInvocations.first?.error.localizedDescription)
        XCTAssertEqual(expectedScope, client.captureErrorWithScopeInvocations.first?.scope)
    }
    
    func assertExceptionCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count)
        XCTAssertEqual(fixture.exception, client.captureExceptionWithScopeInvocations.first?.exception)
        XCTAssertEqual(expectedScope, client.captureExceptionWithScopeInvocations.first?.scope)
    }
    
    func assertMessageCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureMessageWithScopeInvocations.count)
        XCTAssertEqual(fixture.message, client.captureMessageWithScopeInvocations.first?.message)
        XCTAssertEqual(expectedScope, client.captureMessageWithScopeInvocations.first?.scope)
    }
    
    func assertHubScopeNotChanged() {
        let hubScope = SentrySDK.currentHub().scope
        XCTAssertEqual(fixture.scope, hubScope)
    }
    
    func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: fixture.currentDate.date().addingTimeInterval(bySeconds))
    }
}
