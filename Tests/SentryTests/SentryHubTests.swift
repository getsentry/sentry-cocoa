import XCTest

class SentryHubTests: XCTestCase {
    
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
        let sentryCrash = TestSentryCrashWrapper()
        let fileManager: SentryFileManager
        let crashedSession: SentrySession
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString
            options.environment = "debug"
            
            scope.add(crumb)
            
            event = Event()
            event.message = SentryMessage(formatted: message)
            
            fileManager = try! SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: currentDateProvider)
            
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
            let hub = SentryHub(client: client, andScope: scope, andSentryCrashWrapper: sentryCrash)
            hub.bindClient(client)
            return hub
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryHub!
    
    override func setUp() {
        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteTimestampLastInForeground()
        
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteTimestampLastInForeground()
    }

    func testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb() {
        let hub = fixture.getSut()
        // TODO: Add a better API
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        hub.add(crumb)
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"]
        XCTAssertNotNil(scopeBreadcrumbs)
    }
    
    func testBeforeBreadcrumbWithCallbackReturningNullDropsBreadcrumb() {
        let options = fixture.options
        options.beforeBreadcrumb = { crumb in return nil }
        
        sut = fixture.getSut(options, nil)
        
        let crumb = Breadcrumb(
            level: .error,
            category: "default")
        sut.add(crumb)
        let scope = sut.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"]
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
        let options = Options()
        options.beforeBreadcrumb = { crumb in
            return nil
        }
        let hub = fixture.getSut(options)
        
        hub.add(fixture.crumb)
        
        let scope = hub.getScope()
        XCTAssertNil(scope.serialize()["breadcrumbs"])
    }
    
    func testAddBreadcrumb_WithCallbackModifies() {
        let crumbMessage = "modified"
        let options = Options()
        options.beforeBreadcrumb = { crumb in
            crumb.message = crumbMessage
            return crumb
        }
        let hub = fixture.getSut(options)
        
        hub.add(fixture.crumb)
        
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"] as? [[String: Any]]
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
        
        let scope = hub.getScope()

        let scopeSerialized = scope.serialize()
        let scopeUser = scopeSerialized["user"] as? [String: Any?]
        let scopeUserId = scopeUser?["id"] as? String

        XCTAssertEqual(scopeUserId, "123")
    }
    
    func testCaptureEventWithScope() {
        fixture.getSut().capture(event: fixture.event, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeArguments.count)
        if let eventArguments = fixture.client.captureEventWithScopeArguments.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.first.eventId)
            XCTAssertEqual(fixture.scope, eventArguments.second)
        }
    }
    
    func testCaptureEventWithoutScope() {
        fixture.getSut().capture(event: fixture.event)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeArguments.count)
        if let eventArguments = fixture.client.captureEventWithScopeArguments.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.first.eventId)
            XCTAssertEqual(Scope(), eventArguments.second)
        }
    }
    
    func testCaptureMessageWithScope() {
        fixture.getSut().capture(message: fixture.message, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeArguments.count)
        if let messageArguments = fixture.client.captureMessageWithScopeArguments.first {
            XCTAssertEqual(fixture.message, messageArguments.first)
            XCTAssertEqual(fixture.scope, messageArguments.second)
        }
    }
    
    func testCaptureMessageWithoutScope() {
        fixture.getSut().capture(message: fixture.message)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeArguments.count)
        if let messageArguments = fixture.client.captureMessageWithScopeArguments.first {
            XCTAssertEqual(fixture.message, messageArguments.first)
            XCTAssertEqual(Scope(), messageArguments.second)
        }
    }
    
    func testCatpureErrorWithScope() {
        fixture.getSut().capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeArguments.count)
        if let errorArguments = fixture.client.captureErrorWithScopeArguments.first {
            XCTAssertEqual(fixture.error, errorArguments.first as NSError)
            XCTAssertEqual(fixture.scope, errorArguments.second)
        }
    }
    
    func testCatpureErrorWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithSessionArguments.count)
        if let errorArguments = fixture.client.captureErrorWithSessionArguments.first {
            let actualSession = errorArguments.second
            
            XCTAssertEqual(fixture.error, errorArguments.first as NSError)
            
            XCTAssertEqual(1, actualSession.errors)
            XCTAssertEqual(SentrySessionStatus.ok, actualSession.status)
            
            XCTAssertEqual(fixture.scope, errorArguments.third)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.sessions.count)
    }
    
    func testCatpureErrorWithoutScope() {
        fixture.getSut().capture(error: fixture.error).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeArguments.count)
        if let errorArguments = fixture.client.captureErrorWithScopeArguments.first {
            XCTAssertEqual(fixture.error, errorArguments.first as NSError)
            let actualScope = errorArguments.second
            XCTAssertEqual(Scope(), actualScope)
        }
    }
    
    func testCatpureExceptionWithScope() {
        fixture.getSut().capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeArguments.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeArguments.first {
            XCTAssertEqual(fixture.exception, errorArguments.first)
            XCTAssertEqual(fixture.scope, errorArguments.second)
        }
    }
    
    func testCatpureExceptionWithoutScope() {
        fixture.getSut().capture(exception: fixture.exception).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeArguments.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeArguments.first {
            XCTAssertEqual(fixture.exception, errorArguments.first)
            let actualScope = errorArguments.second
            XCTAssertEqual(Scope(), actualScope)
        }
    }
    
    func testCatpureExceptionWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithSessionArguments.count)
        if let exceptionArguments = fixture.client.captureExceptionWithSessionArguments.first {
            XCTAssertEqual(fixture.exception, exceptionArguments.first)
            
            let actualSession = exceptionArguments.second
            XCTAssertEqual(1, actualSession.errors)
            XCTAssertEqual(SentrySessionStatus.ok, actualSession.status)
            
            XCTAssertEqual(fixture.scope, exceptionArguments.third)
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
        for i in Array(0...9) {
            let arguments = fixture.client.captureExceptionWithSessionArguments[i]
            XCTAssertEqual(i + 1, Int(arguments.second.errors))
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
        for i in Array(0...9) {
            let arguments = fixture.client.captureErrorWithSessionArguments[i]
            XCTAssertEqual(i + 1, Int(arguments.second.errors))
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
        assertEventSent()
    }
    
    func testCaptureCrashEvent_CrashedSessionDoesNotExist() {
        sut.startSession() // there is already an existing session
        sut.captureCrash(fixture.event)

        assertNoCrashedSessionSent()
        assertEventSent()
    }
    
    /**
     * When autoSessionTracking is just enabled and there is a previous crash on the disk there is no session on the disk.
     */
    func testCatpureCrashEvent_CrashExistsButNoSessionExists() {
        sut.captureCrash(fixture.event)
        
        assertEventSent()
    }
    
    func testCaptureCrashEvent_WithoutExistingSessionAndAutoSessionTrackingEnabled() {
        givenAutoSessionTrackingDisabled()
        
        sut.captureCrash(fixture.event)
        
        assertEventSent()
    }
    
    func testCaptureCrashEvent_SessionExistsButAutoSessionTrackingDisabled() {
        givenAutoSessionTrackingDisabled()
        givenCrashedSession()
    
        sut.captureCrash(fixture.event)
        
        assertEventSent()
    }
    
    func testCaptureCrashEvent_ClientIsNil() {
        sut = fixture.getSut()
        sut.bindClient(nil)
        
        givenCrashedSession()
        sut.captureCrash(fixture.event)
        
        assertNoEventsSent()
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
        for _ in Array(0...count - 1) {
            group.enter()
            queue.async {
                capture(sut)
                group.leave()
            }
        }

        queue.activate()
        group.waitWithTimeout()
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
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }

    private func assert(withScopeBreadcrumbsCount count: Int, with hub: SentryHub) {
        let scope = hub.getScope()
        let scopeBreadcrumbs = scope.serialize()["breadcrumbs"] as? [AnyHashable]
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
        XCTAssertEqual(0, fixture.client.captureEventWithSessionArguments.count)
    }
    
    private func assertEventSent() {
        let arguments = fixture.client.captureEventWithScopeArguments
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.first)
    }

    private func assertEventSentWithSession() {
        let arguments = fixture.client.captureEventWithSessionArguments
        XCTAssertEqual(1, arguments.count)

        let argument = arguments.first
        XCTAssertEqual(fixture.event, argument?.first)

        let session = argument?.second
        XCTAssertEqual(fixture.currentDateProvider.date(), session?.timestamp)
        XCTAssertEqual(SentrySessionStatus.crashed, session?.status)
        XCTAssertEqual(fixture.options.environment, session?.environment)

        XCTAssertEqual(fixture.scope, argument?.third)
    }
}
