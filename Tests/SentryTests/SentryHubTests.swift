import XCTest

class SentryHubTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryHubTests")
    private static let dsn = TestConstants.dsn(username: "SentryHubTests")
        
    private class Fixture {
        let options: Options
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User wants to crash", userInfo: nil)
        var client: TestClient!
        let crumb = Breadcrumb(level: .error, category: "default")
        let scope = Scope()
        let message = "some message"
        let event: Event
        let currentDateProvider = TestCurrentDateProvider()
        let sentryCrash = TestSentryCrashAdapter.sharedInstance()
        let fileManager: SentryFileManager
        let crashedSession: SentrySession
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        let random = TestRandom(value: 0.5)
        
        init() {
            options = Options()
            options.dsn = SentryHubTests.dsnAsString
            options.environment = "debug"
            
            scope.add(crumb)
            
            event = Event()
            event.message = SentryMessage(formatted: message)
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDateProvider)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
            
            crashedSession = SentrySession(releaseName: "1.0.0")
            crashedSession.endCrashed(withTimestamp: currentDateProvider.date())
            crashedSession.environment = options.environment
        }
        
        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }
        
        func getSut(_ options: Options, _ scope: Scope? = nil) -> SentryHub {
            client = TestClient(options: options)
            let hub = SentryHub(client: client, andScope: scope, andCrashAdapter: sentryCrash, andCurrentDateProvider: currentDateProvider)
            hub.bindClient(client)
            return hub
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryHub!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAppState()
        fixture.fileManager.deleteTimestampLastInForeground()
        fixture.fileManager.deleteAllEnvelopes()
        
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAppState()
        fixture.fileManager.deleteTimestampLastInForeground()
        fixture.fileManager.deleteAllEnvelopes()
    }

    func testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb() {
        let hub = fixture.getSut()
        // TODO: Add a better API
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        hub.add(crumb)
        let scope = hub.scope
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"]
        XCTAssertNotNil(scopeBreadcrumbs)
    }
    
    func testBeforeBreadcrumbWithCallbackReturningNullDropsBreadcrumb() {
        let options = fixture.options
        options.beforeBreadcrumb = { _ in return nil }
        
        sut = fixture.getSut(options, nil)
        
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        sut.add(crumb)
        let scopeBreadcrumbs = sut.scope.serialize()["breadcrumbs"]
        XCTAssertNil(scopeBreadcrumbs)
    }
    
    func testBreadcrumbLimitThroughOptionsUsingHubAddBreadcrumb() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 10)

        for _ in 0...10 {
            let crumb = Breadcrumb(
                level: .error,
                category: "default")
            hub.add(crumb)
        }

        assert(withScopeBreadcrumbsCount: 10, with: hub)
    }
    
    func testBreadcrumbLimitThroughOptionsUsingConfigureScope() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 10)

        for _ in 0...10 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 10, with: hub)
    }
    
    func testBreadcrumbCapLimit() {
        let hub = fixture.getSut()

        for _ in 0...100 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 100, with: hub)
    }
    
    func testBreadcrumbOverDefaultLimit() {
        let hub = fixture.getSut(withMaxBreadcrumbs: 200)

        for _ in 0...200 {
            addBreadcrumbThroughConfigureScope(hub)
        }

        assert(withScopeBreadcrumbsCount: 200, with: hub)
    }
    
    func testAddBreadcrumb_WithCallbackReturnsNil() {
        let options = fixture.options
        options.beforeBreadcrumb = { _ in
            return nil
        }
        let hub = fixture.getSut(options)
        
        hub.add(fixture.crumb)
        
        XCTAssertNil(hub.scope.serialize()["breadcrumbs"])
    }
    
    func testAddBreadcrumb_WithCallbackModifies() {
        let crumbMessage = "modified"
        let options = fixture.options
        options.beforeBreadcrumb = { crumb in
            crumb.message = crumbMessage
            return crumb
        }
        let hub = fixture.getSut(options)
        
        hub.add(fixture.crumb)
        
        let scopeBreadcrumbs = hub.scope.serialize()["breadcrumbs"] as? [[String: Any]]
        XCTAssertNotNil(scopeBreadcrumbs)
        XCTAssertEqual(1, scopeBreadcrumbs?.count)
        XCTAssertEqual(crumbMessage, scopeBreadcrumbs?.first?["message"] as? String)
    }
    
    func testAddUserToTheScope() {
        let client = Client(options: fixture.options)
        let hub = SentryHub(client: client, andScope: Scope())

        let user = User()
        user.userId = "123"
        hub.setUser(user)

        let scopeSerialized = hub.scope.serialize()
        let scopeUser = scopeSerialized["user"] as? [String: Any?]
        let scopeUserId = scopeUser?["id"] as? String

        XCTAssertEqual(scopeUserId, "123")
    }
    
    func testCaptureEventWithScope() {
        fixture.getSut().capture(event: fixture.event, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeArguments.count)
        if let eventArguments = fixture.client.captureEventWithScopeArguments.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.event.eventId)
            XCTAssertEqual(fixture.scope, eventArguments.scope)
        }
    }
    
    func testCaptureEventWithoutScope() {
        fixture.getSut().capture(event: fixture.event)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeArguments.count)
        if let eventArguments = fixture.client.captureEventWithScopeArguments.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.event.eventId)
            XCTAssertEqual(Scope(), eventArguments.scope)
        }
    }
    
    func testStartTransactionWithNameOperation() {
        let span = fixture.getSut().startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        let tracer = Dynamic(span)
        XCTAssertEqual(tracer.name, fixture.transactionName)
        XCTAssertEqual(span.context.operation, fixture.transactionOperation)
    }
    
    func testStartTransactionWithContext() {
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation))
        
        let tracer = Dynamic(span)
        XCTAssertEqual(tracer.name, fixture.transactionName)
        XCTAssertEqual(span.context.operation, fixture.transactionOperation)
    }
    
    func testStartTransactionWithContextSamplingContext() {
        var customSamplingContext: [String: Any]?
        
        let options = fixture.options
        options.tracesSampler = {(context: SamplingContext) -> NSNumber in
            customSamplingContext = context.customSamplingContext
            return 0
        }
        
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), customSamplingContext: ["customKey": "customValue"])
        
        let tracer = Dynamic(span)
        XCTAssertEqual(tracer.name, fixture.transactionName)
        XCTAssertEqual(customSamplingContext?["customKey"] as? String, "customValue")
        XCTAssertEqual(span.context.operation, fixture.transactionOperation)
    }
    
    func testStartTransactionNotSamplingUsingSampleRate() {
        testSampler(expected: .no) { options in
            options.tracesSampler = { _ in return 0.49 }
        }
    }
    
    func testStartTransactionSamplingUsingSampleRate() {
        testSampler(expected: .yes) { options in
            options.tracesSampler = { _ in return 0.5 }
        }
    }
    
    func testStartTransactionNotSamplingUsingTracesSampler() {
        testSampler(expected: .no) { options in
            options.tracesSampler = { _ in return 0.4 }
        }
    }
    
    func testStartTransactionSamplingUsingTracesSampler() {
        testSampler(expected: .yes) { options in
            options.tracesSampler = { _ in return 0.6 }
        }
    }
    
    func testStartTransaction_WhenSampleRateAndSamplerNil() {
        testSampler(expected: SentrySampleDecision.no) { options in
            options.tracesSampleRate = nil
            options.tracesSampler = { _ in return nil }
        }
    }
    
    func testStartTransaction_WhenTracesSamplerOutOfRange_TooBig() {
        testSampler(expected: .no) { options in
            options.tracesSampler = { _ in return 1.01 }
        }
    }
    
    func testStartTransaction_WhenTracesSamplersOutOfRange_TooSmall() {
        testSampler(expected: .no) { options in
            options.tracesSampler = { _ in return -0.01 }
        }
        
        let hub = fixture.getSut()
        Dynamic(hub).sampler.random = fixture.random
        
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        XCTAssertEqual(span.context.sampled, .no)
    }
        
    func testCaptureMessageWithScope() {
        fixture.getSut().capture(message: fixture.message, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeArguments.count)
        if let messageArguments = fixture.client.captureMessageWithScopeArguments.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(fixture.scope, messageArguments.scope)
        }
    }
    
    func testCaptureMessageWithoutScope() {
        fixture.getSut().capture(message: fixture.message)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeArguments.count)
        if let messageArguments = fixture.client.captureMessageWithScopeArguments.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(Scope(), messageArguments.scope)
        }
    }
    
    func testCatpureErrorWithScope() {
        fixture.getSut().capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeArguments.count)
        if let errorArguments = fixture.client.captureErrorWithScopeArguments.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCatpureErrorWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithSessionArguments.count)
        if let errorArguments = fixture.client.captureErrorWithSessionArguments.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            
            XCTAssertEqual(1, errorArguments.session.errors)
            XCTAssertEqual(SentrySessionStatus.ok, errorArguments.session.status)
            
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.sessions.count)
    }
    
    func testCatpureErrorWithoutScope() {
        fixture.getSut().capture(error: fixture.error).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeArguments.count)
        if let errorArguments = fixture.client.captureErrorWithScopeArguments.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(Scope(), errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithScope() {
        fixture.getSut().capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeArguments.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeArguments.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithoutScope() {
        fixture.getSut().capture(exception: fixture.exception).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeArguments.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeArguments.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(Scope(), errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithSessionArguments.count)
        if let exceptionArguments = fixture.client.captureExceptionWithSessionArguments.first {
            XCTAssertEqual(fixture.exception, exceptionArguments.exception)
            
            XCTAssertEqual(1, exceptionArguments.session.errors)
            XCTAssertEqual(SentrySessionStatus.ok, exceptionArguments.session.status)
            
            XCTAssertEqual(fixture.scope, exceptionArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.sessions.count)
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testCatpureMultipleExceptionWithSessionInParallel() {
        captureConcurrentWithSession(count: 10) { sut in
            sut.capture(exception: self.fixture.exception, scope: self.fixture.scope)
        }
        
        XCTAssertEqual(10, fixture.client.captureExceptionWithSessionArguments.count)
        for i in 0...9 {
            let arguments = fixture.client.captureExceptionWithSessionArguments[i]
            XCTAssertEqual(i + 1, Int(arguments.session.errors))
        }
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testCatpureMultipleErrorsWithSessionInParallel() {
        captureConcurrentWithSession(count: 10) { sut in
            sut.capture(error: self.fixture.error, scope: self.fixture.scope)
        }
        
        XCTAssertEqual(10, fixture.client.captureErrorWithSessionArguments.count)
        for i in 0...9 {
            let arguments = fixture.client.captureErrorWithSessionArguments[i]
            XCTAssertEqual(i + 1, Int(arguments.session.errors))
        }
    }
    
    func testCaptureClientIsNil_ReturnsEmptySentryId() {
        sut.bindClient(nil)
        
        XCTAssertEqual(SentryId.empty, sut.capture(error: fixture.error))
        XCTAssertEqual(0, fixture.client.captureErrorWithScopeArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(message: fixture.message, scope: fixture.scope))
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(event: fixture.event))
        XCTAssertEqual(0, fixture.client.captureEventArguments.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(exception: fixture.exception))
        XCTAssertEqual(0, fixture.client.captureExceptionWithScopeArguments.count)
    }
    
    func testCaptureCrashEvent_CrashedSessionExists() {
        sut = fixture.getSut(fixture.options, fixture.scope)
        givenCrashedSession()
        
        assertNoCrashedSessionSent()

        sut.captureCrash(fixture.event)
        
        assertEventSentWithSession()
        
        // Make sure further crash events are sent
        sut.captureCrash(fixture.event)
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_CrashedSessionDoesNotExist() {
        sut.startSession() // there is already an existing session
        sut.captureCrash(fixture.event)

        assertNoCrashedSessionSent()
        assertCrashEventSent()
    }
    
    /**
     * When autoSessionTracking is just enabled and there is a previous crash on the disk there is no session on the disk.
     */
    func testCatpureCrashEvent_CrashExistsButNoSessionExists() {
        sut.captureCrash(fixture.event)
        
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_WithoutExistingSessionAndAutoSessionTrackingEnabled() {
        givenAutoSessionTrackingDisabled()
        
        sut.captureCrash(fixture.event)
        
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_SessionExistsButAutoSessionTrackingDisabled() {
        givenAutoSessionTrackingDisabled()
        givenCrashedSession()
    
        sut.captureCrash(fixture.event)
        
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_ClientIsNil() {
        sut = fixture.getSut()
        sut.bindClient(nil)
        
        givenCrashedSession()
        sut.captureCrash(fixture.event)
        
        assertNoEventsSent()
    }
    
    func testCaptureEnvelope_WithEventWithError() {
        sut.startSession()
        
        captureEventEnvelope(level: SentryLevel.error)
        
        assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithFatal() {
        sut.startSession()
        
        captureEventEnvelope(level: SentryLevel.fatal)
        
        assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithNoLevel() throws {
        sut.startSession()
        
        let envelope = try givenEnvelopeWithModifiedEvent { eventDict in
            eventDict.removeValue(forKey: "level")
        }
        sut.capture(envelope: envelope)
        
        assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithGarbageLevel() throws {
        sut.startSession()
        
        let envelope = try givenEnvelopeWithModifiedEvent { eventDict in
            eventDict["level"] = "Garbage"
        }
        sut.capture(envelope: envelope)
        
        assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithFatal_SessionNotStarted() {
        captureEventEnvelope(level: SentryLevel.fatal)
        
        assertNoSessionAddedToCapturedEnvelope()
    }
    
    func testCaptureEnvelope_WithEventWithWarning() {
        sut.startSession()
        
        captureEventEnvelope(level: SentryLevel.warning)
        
        assertNoSessionAddedToCapturedEnvelope()
    }
    
    func testCaptureEnvelope_WithClientNil() {
        sut.bindClient(nil)
        captureEventEnvelope(level: SentryLevel.warning)
        
        assertNoEnvelopesCaptured()
    }
    
    func testCaptureEnvelope_WithSession() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: ""))
        sut.capture(envelope: envelope)
        
        XCTAssertEqual(1, fixture.client.capturedEnvelopes.count)
        XCTAssertEqual(envelope, fixture.client.capturedEnvelopes.first)
    }

    private func addBreadcrumbThroughConfigureScope(_ hub: SentryHub) {
        hub.configureScope({ scope in
            scope.add(self.fixture.crumb)
        })
    }

    // Altough we only run this test above the below specified versions, we exped the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    private func captureConcurrentWithSession(count: Int, _ capture: @escaping (SentryHub) -> Void) {
        let sut = fixture.getSut()
        sut.startSession()

        let queue = DispatchQueue(label: "SentryHubTests", qos: .utility, attributes: [.concurrent, .initiallyInactive])

        let group = DispatchGroup()
        for _ in 0...count - 1 {
            group.enter()
            queue.async {
                capture(sut)
                group.leave()
            }
        }

        queue.activate()
        group.waitWithTimeout()
    }
    
    private func captureEventEnvelope(level: SentryLevel) {
        let event = TestData.event
        event.level = level
        sut.capture(envelope: SentryEnvelope(event: event))
    }
    
    private func givenCrashedSession() {
        fixture.sentryCrash.internalCrashedLastLaunch = true
        fixture.fileManager.storeCrashedSession(fixture.crashedSession)
        sut.closeCachedSession(withTimestamp: fixture.currentDateProvider.date())
        sut.startSession()
    }
    
    private func givenAutoSessionTrackingDisabled() {
        let options = fixture.options
        options.enableAutoSessionTracking = false
        sut = fixture.getSut(options)
    }
    
    private func givenEnvelopeWithModifiedEvent(modifyEventDict: (inout [String: Any]) -> Void) throws -> SentryEnvelope {
        let event = TestData.event
        let envelopeItem = SentryEnvelopeItem(event: event)
        var eventDict = try JSONSerialization.jsonObject(with: envelopeItem.data) as! [String: Any]
        
        modifyEventDict(&eventDict)
        
        let eventData = try JSONSerialization.data(withJSONObject: eventDict)
        return SentryEnvelope(header: SentryEnvelopeHeader(id: event.eventId), items: [SentryEnvelopeItem(header: envelopeItem.header, data: eventData)])
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }

    private func assert(withScopeBreadcrumbsCount count: Int, with hub: SentryHub) {
        let scopeBreadcrumbs = hub.scope.serialize()["breadcrumbs"] as? [AnyHashable]
        XCTAssertNotNil(scopeBreadcrumbs)
        XCTAssertEqual(scopeBreadcrumbs?.count, count)
    }

    private func assertSessionDeleted() {
        XCTAssertNil(fixture.fileManager.readCurrentSession())
    }
    
    private func assertNoCrashedSessionSent() {
        XCTAssertFalse(fixture.client.sessions.contains(where: { session in
            return session.status == SentrySessionStatus.crashed
        }))
    }
    
    private func assertNoEventsSent() {
        XCTAssertEqual(0, fixture.client.captureEventArguments.count)
        XCTAssertEqual(0, fixture.client.captureCrashEventWithSessionArguments.count)
    }
    
    private func assertEventSent() {
        let arguments = fixture.client.captureEventWithScopeArguments
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
    }
    
    private func assertCrashEventSent() {
        let arguments = fixture.client.captureCrashEventArguments
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
    }

    private func assertEventSentWithSession() {
        let arguments = fixture.client.captureCrashEventWithSessionArguments
        XCTAssertEqual(1, arguments.count)

        let argument = arguments.first
        XCTAssertEqual(fixture.event, argument?.event)

        let session = argument?.session
        XCTAssertEqual(fixture.currentDateProvider.date(), session?.timestamp)
        XCTAssertEqual(SentrySessionStatus.crashed, session?.status)
        XCTAssertEqual(fixture.options.environment, session?.environment)

        XCTAssertEqual(fixture.scope, argument?.scope)
    }
    
    private func assertSessionWithIncrementedErrorCountedAdded() {
        XCTAssertEqual(1, fixture.client.capturedEnvelopes.count)
        let envelope = fixture.client.capturedEnvelopes.first!
        XCTAssertEqual(2, envelope.items.count)
        let session = SentrySerialization.session(with: envelope.items[1].data)
        XCTAssertEqual(1, session?.errors)
    }
    
    private func assertNoSessionAddedToCapturedEnvelope() {
        XCTAssertEqual(1, fixture.client.capturedEnvelopes.count)
        let envelope = fixture.client.capturedEnvelopes.first!
        XCTAssertEqual(1, envelope.items.count)
    }
    
    private func assertNoEnvelopesCaptured() {
        XCTAssertEqual(0, fixture.client.capturedEnvelopes.count)
    }
    
    private func testSampler(expected: SentrySampleDecision, options: (Options) -> Void) {
        options(fixture.options)
        
        let hub = fixture.getSut()
        Dynamic(hub).sampler.random = fixture.random
        
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        
        XCTAssertEqual(expected, span.context.sampled)
    }
}
