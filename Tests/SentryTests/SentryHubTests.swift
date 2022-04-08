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
        let sentryCrash = TestSentryCrashWrapper.sharedInstance()
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
            let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: sentryCrash, andCurrentDateProvider: currentDateProvider)
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
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeInvocations.count)
        if let eventArguments = fixture.client.captureEventWithScopeInvocations.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.event.eventId)
            XCTAssertEqual(fixture.scope, eventArguments.scope)
        }
    }
    
    func testCaptureEventWithoutScope() {
        fixture.getSut().capture(event: fixture.event)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeInvocations.count)
        if let eventArguments = fixture.client.captureEventWithScopeInvocations.first {
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

    func testStartTransactionSamplingUsingTracesSampler() {
        testSampler(expected: .yes) { options in
            options.tracesSampler = { _ in return 0.51 }
        }
    }
    
    func testStartTransaction_WhenSampleRateAndSamplerNil() {
        testSampler(expected: .no) { options in
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

    func testCaptureSampledTransaction_ReturnsEmptyId() {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        let id = sut.capture(trans as! Transaction, with: Scope())
        id.assertIsEmpty()
    }

    func testCaptureSampledTransaction_RecordsLostEvent() {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(trans as! Transaction, with: Scope())

        XCTAssertEqual(1, fixture.client.recordLostEvents.count)
        let lostEvent = fixture.client.recordLostEvents.first
        XCTAssertEqual(.transaction, lostEvent?.category)
        XCTAssertEqual(.sampleRate, lostEvent?.reason)
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func testStartTransaction_WhenProfilingEnabled_CapturesProfile() {
        let options = fixture.options
        options.enableProfiling = true
        options.tracesSampler = {(_: SamplingContext) -> NSNumber in
            return 1
        }
        let hub = fixture.getSut(options)
        let profileExpectation = expectation(description: "collects profiling data")
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        // Give it time to collect a profile, otherwise there will be no samples.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            span.finish()

            guard let additionalEnvelopeItems = self.fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
                XCTFail("Expected to capture at least 1 event")
                return
            }
            XCTAssertEqual(1, additionalEnvelopeItems.count)
            guard let profileItem = additionalEnvelopeItems.first else {
                XCTFail("Expected at least 1 additional envelope item")
                return
            }
            XCTAssertEqual("profile", profileItem.header.type)
            self.assertValidProfileData(data: profileItem.data)
            profileExpectation.fulfill()
        }
        
        // Some busy work to try and get it to show up in the profile.
        let str = "a"
        var concatStr = ""
        for _ in 0..<100_000 {
            concatStr = concatStr.appending(str)
        }
        
        waitForExpectations(timeout: 5.0) {
            if let error = $0 {
                print(error)
            }
        }
    }
    
    func testStartTransaction_WhenProfilingDisabled_DoesNotCaptureProfile() {
        let options = fixture.options
        options.enableProfiling = false
        options.tracesSampler = {(_: SamplingContext) -> NSNumber in
            return 1
        }
        let hub = fixture.getSut(options)
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        span.finish()
        
        guard let additionalEnvelopeItems = fixture.client.captureEventWithScopeInvocations.first?.additionalEnvelopeItems else {
            XCTFail("Expected to capture at least 1 event")
            return
        }
        XCTAssertEqual(0, additionalEnvelopeItems.count)
    }
#endif
        
    func testCaptureMessageWithScope() {
        fixture.getSut().capture(message: fixture.message, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeInvocations.count)
        if let messageArguments = fixture.client.captureMessageWithScopeInvocations.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(fixture.scope, messageArguments.scope)
        }
    }
    
    func testCaptureMessageWithoutScope() {
        fixture.getSut().capture(message: fixture.message)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeInvocations.count)
        if let messageArguments = fixture.client.captureMessageWithScopeInvocations.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(Scope(), messageArguments.scope)
        }
    }
    
    func testCatpureErrorWithScope() {
        fixture.getSut().capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithScopeInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCatpureErrorWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithSessionInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithSessionInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            
            XCTAssertEqual(1, errorArguments.session.errors)
            XCTAssertEqual(SentrySessionStatus.ok, errorArguments.session.status)
            
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    func testCatpureErrorWithoutScope() {
        fixture.getSut().capture(error: fixture.error).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithScopeInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(Scope(), errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithScope() {
        fixture.getSut().capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeInvocations.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithoutScope() {
        fixture.getSut().capture(exception: fixture.exception).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeInvocations.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(Scope(), errorArguments.scope)
        }
    }
    
    func testCatpureExceptionWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithSessionInvocations.count)
        if let exceptionArguments = fixture.client.captureExceptionWithSessionInvocations.first {
            XCTAssertEqual(fixture.exception, exceptionArguments.exception)
            
            XCTAssertEqual(1, exceptionArguments.session.errors)
            XCTAssertEqual(SentrySessionStatus.ok, exceptionArguments.session.status)
            
            XCTAssertEqual(fixture.scope, exceptionArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testCatpureMultipleExceptionWithSessionInParallel() {
        let captureCount = 100
        captureConcurrentWithSession(count: captureCount) { sut in
            sut.capture(exception: self.fixture.exception, scope: self.fixture.scope)
        }
        
        let invocations = fixture.client.captureExceptionWithSessionInvocations.invocations
        XCTAssertEqual(captureCount, invocations.count)
        for i in 1...captureCount {
            // The session error count must not be in order as we use a concurrent DispatchQueue
            XCTAssertTrue(
                invocations.contains { $0.session.errors == i },
                "No session captured with \(i) amount of errors."
            )
        }
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testCatpureMultipleErrorsWithSessionInParallel() {
        let captureCount = 100
        captureConcurrentWithSession(count: captureCount) { sut in
            sut.capture(error: self.fixture.error, scope: self.fixture.scope)
        }
        
        let invocations = fixture.client.captureErrorWithSessionInvocations.invocations
        XCTAssertEqual(captureCount, invocations.count)
        for i in 1..<captureCount {
            // The session error count must not be in order as we use a concurrent DispatchQueue
            XCTAssertTrue(
                invocations.contains { $0.session.errors == i },
                "No session captured with \(i) amount of errors."
            )
        }
    }
    
    func testCaptureClientIsNil_ReturnsEmptySentryId() {
        sut.bindClient(nil)
        
        XCTAssertEqual(SentryId.empty, sut.capture(error: fixture.error))
        XCTAssertEqual(0, fixture.client.captureErrorWithScopeInvocations.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(message: fixture.message, scope: fixture.scope))
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeInvocations.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(event: fixture.event))
        XCTAssertEqual(0, fixture.client.captureEventInvocations.count)
        
        XCTAssertEqual(SentryId.empty, sut.capture(exception: fixture.exception))
        XCTAssertEqual(0, fixture.client.captureExceptionWithScopeInvocations.count)
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
        
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, fixture.client.captureEnvelopeInvocations.first)
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

        let queue = DispatchQueue(label: "SentryHubTests", qos: .utility, attributes: [.concurrent])

        let group = DispatchGroup()
        for _ in 0..<count {
            group.enter()
            queue.async {
                capture(sut)
                group.leave()
            }
        }

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
        return SentryEnvelope(header: SentryEnvelopeHeader(id: event.eventId, traceState: nil), items: [SentryEnvelopeItem(header: envelopeItem.header, data: eventData)])
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
        XCTAssertFalse(fixture.client.captureSessionInvocations.invocations.contains(where: { session in
            return session.status == SentrySessionStatus.crashed
        }))
    }
    
    private func assertNoEventsSent() {
        XCTAssertEqual(0, fixture.client.captureEventInvocations.count)
        XCTAssertEqual(0, fixture.client.captureCrashEventWithSessionInvocations.count)
    }
    
    private func assertEventSent() {
        let arguments = fixture.client.captureEventWithScopeInvocations
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
    }
    
    private func assertCrashEventSent() {
        let arguments = fixture.client.captureCrashEventInvocations
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
    }

    private func assertEventSentWithSession() {
        let arguments = fixture.client.captureCrashEventWithSessionInvocations
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
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        let envelope = fixture.client.captureEnvelopeInvocations.first!
        XCTAssertEqual(2, envelope.items.count)
        let session = SentrySerialization.session(with: envelope.items[1].data)
        XCTAssertEqual(1, session?.errors)
    }
    
    private func assertNoSessionAddedToCapturedEnvelope() {
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        let envelope = fixture.client.captureEnvelopeInvocations.first!
        XCTAssertEqual(1, envelope.items.count)
    }
    
    private func assertNoEnvelopesCaptured() {
        XCTAssertEqual(0, fixture.client.captureEnvelopeInvocations.count)
    }
    
    private func assertValidProfileData(data: Data) {
        let profile = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual("Apple", profile["device_manufacturer"] as! String)
        XCTAssertEqual("cocoa", profile["platform"] as! String)
        XCTAssertEqual(fixture.transactionName, profile["transaction_name"] as! String)
#if os(iOS)
        XCTAssertEqual("iOS", profile["device_os_name"] as! String)
        XCTAssertFalse((profile["device_os_version"] as! String).isEmpty)
#endif
        XCTAssertFalse((profile["device_os_build_number"] as! String).isEmpty)
        XCTAssertFalse((profile["device_locale"] as! String).isEmpty)
        XCTAssertFalse((profile["device_model"] as! String).isEmpty)
#if os(iOS) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(profile["device_is_emulator"] as! Bool)
#else
        XCTAssertFalse(profile["device_is_emulator"] as! Bool)
#endif
        XCTAssertFalse((profile["device_physical_memory_bytes"] as! String).isEmpty)
        XCTAssertFalse((profile["version_code"] as! String).isEmpty)
        
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["transaction_id"] as! String))
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["profile_id"] as! String))
        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: profile["trace_id"] as! String))
        
        XCTAssertFalse(((profile["debug_meta"] as! [String: Any])["images"] as! [Any]).isEmpty)
        let sampledProfile = profile["sampled_profile"] as! [String: Any]
        let samples = sampledProfile["samples"] as! [[String: Any]]
        XCTAssertFalse(samples.isEmpty)
        
        let frames = samples[0]["frames"] as! [[String: Any]]
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse((frames[0]["instruction_addr"] as! String).isEmpty)
    }
    
    private func testSampler(expected: SentrySampleDecision, options: (Options) -> Void) {
        options(fixture.options)
        
        let hub = fixture.getSut()
        Dynamic(hub).sampler.random = fixture.random
        
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        
        XCTAssertEqual(expected, span.context.sampled)
    }
}
