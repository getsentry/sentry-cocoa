import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

// swiftlint:disable file_length
class SentryHubTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryHubTests")
    
    private class Fixture {
        let options: Options
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User wants to crash", userInfo: nil)
        lazy var client = TestClient(options: options)!
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
        let traceOrigin = "auto"
        let random = TestRandom(value: 0.5)
        let queue = DispatchQueue(label: "SentryHubTests", qos: .utility, attributes: [.concurrent])
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        
        init() {
            options = Options()
            options.dsn = SentryHubTests.dsnAsString
            
            scope.addBreadcrumb(crumb)
            
            event = Event()
            event.message = SentryMessage(formatted: message)
            
            fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
            
            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
            SentryDependencyContainer.sharedInstance().random = random
            
            crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "")
            crashedSession.endCrashed(withTimestamp: currentDateProvider.date())
            crashedSession.environment = options.environment
        }
        
        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }
        
        func getSut(_ options: Options, _ scope: Scope? = nil) -> SentryHub {
            let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: sentryCrash, andDispatchQueue: self.dispatchQueueWrapper)
            hub.bindClient(client)
            return hub
        }
    }
    
    private var fixture: Fixture!
    private lazy var sut = fixture.getSut()
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAppState()
        fixture.fileManager.deleteTimestampLastInForeground()
        fixture.fileManager.deleteAllEnvelopes()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAppState()
        fixture.fileManager.deleteTimestampLastInForeground()
        fixture.fileManager.deleteAllEnvelopes()
        clearTestState()
    }
    
    func testCaptureErrorWithRealDSN() {
        let sentryOption = Options()
        sentryOption.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
                
        let scope = Scope()
        let sentryHub = SentryHub(client: SentryClient(options: sentryOption), andScope: scope)

        let error = NSError(domain: "Test.CaptureErrorWithRealDSN", code: 12)
        sentryHub.capture(error: error)
    }
    
    func testBeforeBreadcrumbWithoutCallbackStoresBreadcrumb() {
        let hub = fixture.getSut()
        
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
        // To avoid spamming the test logs
        SentryLog.configure(true, diagnosticLevel: .error)
        
        let hub = fixture.getSut()
        
        for _ in 0...100 {
            addBreadcrumbThroughConfigureScope(hub)
        }
        
        assert(withScopeBreadcrumbsCount: 100, with: hub)
        
        setTestDefaultLogLevel()
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
    
    func testScopeEnriched() {
        let hub = fixture.getSut(fixture.options, Scope())
        expect(hub.scope.contextDictionary.allValues.isEmpty) == false
        expect(hub.scope.contextDictionary["os"]) != nil
        expect(hub.scope.contextDictionary["device"]) != nil
        expect(hub.scope.contextDictionary["app"]) != nil
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
    
    func testAddUserToTheScope() throws {
        let client = SentryClient(options: fixture.options, fileManager: try TestFileManager(options: fixture.options), deleteOldEnvelopeItems: false)
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
        fixture.getSut(fixture.options, fixture.scope).capture(event: fixture.event)
        
        XCTAssertEqual(1, fixture.client.captureEventWithScopeInvocations.count)
        if let eventArguments = fixture.client.captureEventWithScopeInvocations.first {
            XCTAssertEqual(fixture.event.eventId, eventArguments.event.eventId)
            XCTAssertEqual(fixture.scope, eventArguments.scope)
        }
    }
    
    func testStartTransactionWithNameOperation() {
        let span = fixture.getSut().startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        let tracer = span as! SentryTracer
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(span.operation, fixture.transactionOperation)
        XCTAssertEqual(SentryTransactionNameSource.custom, tracer.transactionContext.nameSource)
        XCTAssertEqual("manual", tracer.transactionContext.origin)
    }
    
    func testStartTransactionWithContext() {
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(
            name: fixture.transactionName,
            operation: fixture.transactionOperation
        ))
        
        let tracer = span as! SentryTracer
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(span.operation, fixture.transactionOperation)
        XCTAssertEqual("manual", tracer.transactionContext.origin)
    }
    
    func testStartTransactionWithNameSource() {
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(
            name: fixture.transactionName,
            nameSource: .url,
            operation: fixture.transactionOperation,
            origin: fixture.traceOrigin
        ))
        
        let tracer = span as! SentryTracer
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(tracer.transactionContext.nameSource, SentryTransactionNameSource.url)
        XCTAssertEqual(span.operation, fixture.transactionOperation)
        XCTAssertEqual(tracer.transactionContext.origin, fixture.traceOrigin)
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
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(customSamplingContext?["customKey"] as? String, "customValue")
        XCTAssertEqual(span.operation, fixture.transactionOperation)
    }
    
    func testStartTransaction_checkContextSampleRate_fromOptions() {
        let options = fixture.options
        options.tracesSampleRate = 0.49
        
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), customSamplingContext: ["customKey": "customValue"])
        let context = (span as? SentryTracer)?.transactionContext
        
        XCTAssertEqual(context?.sampleRate, 0.49)
    }
    
    func testStartTransaction_checkContextSampleRate_fromSampler() {
        let options = fixture.options
        options.tracesSampler = {  _ -> NSNumber in
            return NSNumber(value: 0.51)
        }
        
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), customSamplingContext: ["customKey": "customValue"])
        let context = (span as? SentryTracer)?.transactionContext
        
        XCTAssertEqual(context?.sampleRate, 0.51)
    }
    
    func testStartTransactionNotSamplingUsingSampleRate() {
        assertSampler(expected: .no) { options in
            options.tracesSampleRate = 0.49
        }
    }
    
    func testStartTransactionSamplingUsingSampleRate() {
        assertSampler(expected: .yes) { options in
            options.tracesSampleRate = 0.50
        }
    }
    
    func testStartTransactionSamplingUsingTracesSampler() {
        assertSampler(expected: .yes) { options in
            options.tracesSampler = { _ in return 0.51 }
        }
    }
    
    func testStartTransaction_WhenSampleRateAndSamplerNil() {
        assertSampler(expected: .no) { options in
            options.tracesSampleRate = nil
            options.tracesSampler = { _ in return nil }
        }
    }
    
    func testStartTransaction_WhenTracesSamplerOutOfRange_TooBig() {
        assertSampler(expected: .no) { options in
            options.tracesSampler = { _ in return 1.01 }
        }
    }
    
    func testStartTransaction_WhenTracesSamplersOutOfRange_TooSmall() {
        assertSampler(expected: .no) { options in
            options.tracesSampler = { _ in return -0.01 }
        }
        
        let hub = fixture.getSut()
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        XCTAssertEqual(span.sampled, .no)
    }
    
    func testCaptureTransaction_CapturesEventAsync() {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .yes))
        
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(trans as! Transaction, with: Scope())
        
        expect(self.fixture.client.captureEventWithScopeInvocations.count) == 1
        expect(self.fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count) == 1
    }
    
    func testCaptureSampledTransaction_DoesNotCaptureEvent() {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))
        
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(trans as! Transaction, with: Scope())
        
        expect(self.fixture.client.captureEventWithScopeInvocations.count) == 0
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
    
    func testCaptureMessageWithScope() {
        fixture.getSut().capture(message: fixture.message, scope: fixture.scope)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeInvocations.count)
        if let messageArguments = fixture.client.captureMessageWithScopeInvocations.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(fixture.scope, messageArguments.scope)
        }
    }
    
    func testCaptureMessageWithoutScope() {
        fixture.getSut(fixture.options, fixture.scope).capture(message: fixture.message)
        
        XCTAssertEqual(1, fixture.client.captureMessageWithScopeInvocations.count)
        if let messageArguments = fixture.client.captureMessageWithScopeInvocations.first {
            XCTAssertEqual(fixture.message, messageArguments.message)
            XCTAssertEqual(fixture.scope, messageArguments.scope)
        }
    }
    
    func testCaptureErrorWithScope() {
        fixture.getSut().capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithScopeInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCaptureErrorWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithSessionInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithSessionInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            
            XCTAssertEqual(1, errorArguments.session?.errors)
            XCTAssertEqual(SentrySessionStatus.ok, errorArguments.session?.status)
            
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    func testCaptureErrorBeforeSessionStart() {
        let sut = fixture.getSut()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        sut.startSession()
        
        XCTAssertEqual(fixture.client.captureErrorWithScopeInvocations.count, 1)
        XCTAssertEqual(fixture.client.captureSessionInvocations.count, 1)
        
        if let session = fixture.client.captureSessionInvocations.first {
            XCTAssertEqual(session.errors, 1)
        }
    }
    
    func testCaptureErrorBeforeSessionStart_DisabledAutoSessionTracking() {
        fixture.options.enableAutoSessionTracking = false
        let sut = fixture.getSut()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        sut.startSession()
        
        XCTAssertEqual(fixture.client.captureErrorWithScopeInvocations.count, 1)
        XCTAssertEqual(fixture.client.captureSessionInvocations.count, 1)
        
        if let session = fixture.client.captureSessionInvocations.first {
            XCTAssertEqual(session.errors, 0)
        }
    }
    
    func testCaptureError_SessionWithDefaultEnvironment() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(fixture.client.captureSessionInvocations.count, 1)
        
        if let session = fixture.client.captureSessionInvocations.first {
            XCTAssertEqual(session.environment, "production")
        }
    }
    
    func testCaptureError_SessionWithEnvironmentFromOptions() {
        fixture.options.environment = "test-env"
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(fixture.client.captureSessionInvocations.count, 1)
        
        if let session = fixture.client.captureSessionInvocations.first {
            XCTAssertEqual(session.environment, "test-env")
        }
    }
    
    func testCaptureWithoutIncreasingErrorCount() {
        let sut = fixture.getSut()
        sut.startSession()
        fixture.client.callSessionBlockWithIncrementSessionErrors = false
        sut.capture(error: fixture.error, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithSessionInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithSessionInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertNil(errorArguments.session)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    func testCaptureErrorWithoutScope() {
        fixture.getSut(fixture.options, fixture.scope).capture(error: fixture.error).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureErrorWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureErrorWithScopeInvocations.first {
            XCTAssertEqual(fixture.error, errorArguments.error as NSError)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCaptureExceptionWithScope() {
        fixture.getSut().capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeInvocations.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCaptureExceptionWithoutScope() {
        fixture.getSut(fixture.options, fixture.scope).capture(exception: fixture.exception).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithScopeInvocations.count)
        if let errorArguments = fixture.client.captureExceptionWithScopeInvocations.first {
            XCTAssertEqual(fixture.exception, errorArguments.exception)
            XCTAssertEqual(fixture.scope, errorArguments.scope)
        }
    }
    
    func testCaptureExceptionWithSessionWithScope() {
        let sut = fixture.getSut()
        sut.startSession()
        sut.capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithSessionInvocations.count)
        if let exceptionArguments = fixture.client.captureExceptionWithSessionInvocations.first {
            XCTAssertEqual(fixture.exception, exceptionArguments.exception)
            
            XCTAssertEqual(1, exceptionArguments.session?.errors)
            XCTAssertEqual(SentrySessionStatus.ok, exceptionArguments.session?.status)
            
            XCTAssertEqual(fixture.scope, exceptionArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    func testCaptureExceptionWithoutIncreasingErrorCount() {
        let sut = fixture.getSut()
        sut.startSession()
        fixture.client.callSessionBlockWithIncrementSessionErrors = false
        sut.capture(exception: fixture.exception, scope: fixture.scope).assertIsNotEmpty()
        
        XCTAssertEqual(1, fixture.client.captureExceptionWithSessionInvocations.count)
        if let exceptionArguments = fixture.client.captureExceptionWithSessionInvocations.first {
            XCTAssertEqual(fixture.exception, exceptionArguments.exception)
            XCTAssertNil(exceptionArguments.session)
            XCTAssertEqual(fixture.scope, exceptionArguments.scope)
        }
        
        // only session init is sent
        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)
    }
    
    func testCaptureMultipleExceptionWithSessionInParallel() {
        let captureCount = 100
        captureConcurrentWithSession(count: captureCount) { sut in
            sut.capture(exception: self.fixture.exception, scope: self.fixture.scope)
        }
        
        let invocations = fixture.client.captureExceptionWithSessionInvocations.invocations
        XCTAssertEqual(captureCount, invocations.count)
        for i in 1...captureCount {
            // The session error count must not be in order as we use a concurrent DispatchQueue
            XCTAssertTrue(
                invocations.contains { $0.session!.errors == i },
                "No session captured with \(i) amount of errors."
            )
        }
    }
    
    func testCaptureMultipleErrorsWithSessionInParallel() {
        let captureCount = 100
        captureConcurrentWithSession(count: captureCount) { sut in
            sut.capture(error: self.fixture.error, scope: self.fixture.scope)
        }
        
        let invocations = fixture.client.captureErrorWithSessionInvocations.invocations
        XCTAssertEqual(captureCount, invocations.count)
        for i in 1..<captureCount {
            // The session error count must not be in order as we use a concurrent DispatchQueue
            XCTAssertTrue(
                invocations.contains { $0.session!.errors == i },
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
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        sut.captureCrash(fixture.event)
        assertEventSentWithSession(scopeEnvironment: environment)
        
        // Make sure further crash events are sent
        sut.captureCrash(fixture.event)
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_ManualSessionTracking_CrashedSessionExists() {
        givenAutoSessionTrackingDisabled()
        
        givenCrashedSession()
        
        assertNoCrashedSessionSent()
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        sut.captureCrash(fixture.event)
        
        assertEventSentWithSession(scopeEnvironment: environment)
        
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
    func testCaptureCrashEvent_CrashExistsButNoSessionExists() {
        sut.captureCrash(fixture.event)
        
        assertCrashEventSent()
    }
    
    func testCaptureCrashEvent_WithoutExistingSessionAndAutoSessionTrackingEnabled() {
        givenAutoSessionTrackingDisabled()
        
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
    
    func testCaptureEnvelope_WithEventWithoutExceptionMechanism() {
        sut.startSession()
        
        captureFatalEventWithoutExceptionMechanism()
        
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
        sut.capture(envelope)
        
        assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithGarbageLevel() throws {
        sut.startSession()
        
        let envelope = try givenEnvelopeWithModifiedEvent { eventDict in
            eventDict["level"] = "Garbage"
        }
        sut.capture(envelope)
        
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
    
    func testCaptureReplay() {
        class SentryClientMockReplay: SentryClient {
            var replayEvent: SentryReplayEvent?
            var replayRecording: SentryReplayRecording?
            var videoUrl: URL?
            var scope: Scope?
            override func capture(_ replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, video videoURL: URL, with scope: Scope) {
                self.replayEvent = replayEvent
                self.replayRecording = replayRecording
                self.videoUrl = videoURL
                self.scope = scope
            }
        }
        let mockClient = SentryClientMockReplay(options: fixture.options)
        
        let replayEvent = SentryReplayEvent()
        let replayRecording = SentryReplayRecording()
        let videoUrl = URL(string: "https://sentry.io")!
        
        sut.bindClient(mockClient)
        sut.capture(replayEvent, replayRecording: replayRecording, video: videoUrl)
        
        expect(mockClient?.replayEvent) == replayEvent
        expect(mockClient?.replayRecording) == replayRecording
        expect(mockClient?.videoUrl) == videoUrl
        expect(mockClient?.scope) == sut.scope
    }
    
    func testCaptureEnvelope_WithSession() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "", distinctId: ""))
        sut.capture(envelope)
        
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, fixture.client.captureEnvelopeInvocations.first)
    }
    
    func testCaptureEnvelope_WithUnhandledException() {
        sut.startSession()
        
        fixture.currentDateProvider.setDate(date: Date(timeIntervalSince1970: 2))
        
        let event = TestData.event
        event.level = .error
        event.exceptions = [TestData.exception]
        event.exceptions?.first?.mechanism?.handled = false
        sut.capture(SentryEnvelope(event: event))

        //Check whether session was finished as crashed
        let envelope = fixture.client.captureEnvelopeInvocations.first
        let sessionEnvelopeItem = envelope?.items.first(where: { $0.header.type == "session" })
        
        let json = (try! JSONSerialization.jsonObject(with: sessionEnvelopeItem!.data)) as! [String: Any]
        
        XCTAssertEqual(json["timestamp"] as? String, "1970-01-01T00:00:02.000Z")
        XCTAssertEqual(json["status"] as? String, "crashed")
    }
    
    func testCaptureEnvelope_WithHandledException() {
        sut.startSession()
        
        let beginSession = sut.session
        
        let event = TestData.event
        event.level = .error
        event.exceptions = [TestData.exception]
        sut.capture(SentryEnvelope(event: event))
        
        let endSession = sut.session
        
        XCTAssertEqual(beginSession, endSession)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func test_reportFullyDisplayed_enableTimeToFullDisplay_YES() {
        fixture.options.enableTimeToFullDisplayTracing = true
        let sut = fixture.getSut(fixture.options)
        
        let testTTDTracker = TestTimeToDisplayTracker()
        
        Dynamic(SentryUIViewControllerPerformanceTracker.shared).currentTTDTracker = testTTDTracker
        
        sut.reportFullyDisplayed()
        
        XCTAssertTrue(testTTDTracker.registerFullDisplayCalled)
        
    }
    
    func test_reportFullyDisplayed_enableTimeToFullDisplay_NO() {
        fixture.options.enableTimeToFullDisplayTracing = false
        let sut = fixture.getSut(fixture.options)
        
        let testTTDTracker = TestTimeToDisplayTracker()
        
        Dynamic(SentryUIViewControllerPerformanceTracker.shared).currentTTDTracker = testTTDTracker
        
        sut.reportFullyDisplayed()
        
        XCTAssertFalse(testTTDTracker.registerFullDisplayCalled)
    }
#endif
    
    func testStartTransaction_WhenSamplerNil_NotSampled() {
        assertSampler(expected: .no) { options in
            options.tracesSampleRate = 0.49
            options.tracesSampler = { _ in return nil }
        }
    }
    
    func testStartTransaction_WhenSamplerNil_Sampled() {
        assertSampler(expected: .yes) { options in
            options.tracesSampleRate = 0.50
            options.tracesSampler = { _ in return nil }
        }
    }
    
    private func addBreadcrumbThroughConfigureScope(_ hub: SentryHub) {
        hub.configureScope({ scope in
            scope.addBreadcrumb(self.fixture.crumb)
        })
    }
    
    private func captureConcurrentWithSession(count: Int, _ capture: @escaping (SentryHub) -> Void) {
        let sut = fixture.getSut()
        sut.startSession()
        
        let queue = fixture.queue
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
    
    func testModifyIntegrationsConcurrently() {
        
        let sut = fixture.getSut()
        
        let outerLoopAmount = 10
        let innerLoopAmount = 100
        
        let queue = fixture.queue
        let group = DispatchGroup()
        
        for i in 0..<outerLoopAmount {
            group.enter()
            queue.async {
                for j in 0..<innerLoopAmount {
                    let integrationName = "Integration\(i)\(j)"
                    sut.addInstalledIntegration(EmptyIntegration(), name: integrationName)
                    XCTAssertTrue(sut.hasIntegration(integrationName))
                }
                group.leave()
            }
        }
        
        group.waitWithTimeout()
        
        XCTAssertEqual(innerLoopAmount * outerLoopAmount, sut.installedIntegrations().count)
        XCTAssertEqual(innerLoopAmount * outerLoopAmount, sut.installedIntegrationNames().count)
        
    }
    
    /**
     * This test only ensures concurrent modifications don't crash.
     */
    func testModifyIntegrationsConcurrently_NoCrash() {
        let sut = fixture.getSut()
        
        let queue = fixture.queue
        let group = DispatchGroup()
        
        for i in 0..<1_000 {
            group.enter()
            queue.async {
                for j in 0..<10 {
                    let integrationName = "Integration\(i)\(j)"
                    sut.addInstalledIntegration(EmptyIntegration(), name: integrationName)
                    sut.hasIntegration(integrationName)
                    sut.isIntegrationInstalled(EmptyIntegration.self)
                }
                XCTAssertLessThanOrEqual(0, sut.installedIntegrations().count)
                sut.installedIntegrations().forEach { XCTAssertNotNil($0) }
                
                XCTAssertLessThanOrEqual(0, sut.installedIntegrationNames().count)
                sut.installedIntegrationNames().forEach { XCTAssertNotNil($0) }
                sut.removeAllIntegrations()
                
                group.leave()
            }
        }
        
        group.wait()
    }
    
    func testEventContainsOnlyHandledErrors() {
        let sut = fixture.getSut()
        XCTAssertFalse(sut.eventContainsOnlyHandledErrors(["exception":
                                                            ["values":
                                                                [["mechanism": ["handled": false]]]
                                                            ]
                                                          ]))
        
        XCTAssertTrue(sut.eventContainsOnlyHandledErrors(["exception":
                                                            ["values":
                                                                [["mechanism": ["handled": true]],
                                                                 ["mechanism": ["handled": true]]]
                                                            ]
                                                         ]))
        
        XCTAssertFalse(sut.eventContainsOnlyHandledErrors(["exception":
                                                            ["values":
                                                                [["mechanism": ["handled": true]],
                                                                 ["mechanism": ["handled": false]]]
                                                            ]
                                                          ]))
        
        XCTAssertTrue(sut.eventContainsOnlyHandledErrors(["exception":
                                                            ["values":
                                                                [["mechanism": ["handled": true]],
                                                                 ["mechanism": ["other-key": false]]]
                                                            ]
                                                         ]))
    }
    
    func testInitHubWithDefaultOptions_DoesNotEnableMetrics() {
        let sut = fixture.getSut()
        
        sut.metrics.increment(key: "key")
        sut.close()
        
        expect(self.fixture.client.captureEnvelopeInvocations.count) == 0
    }
    
    func testMetrics_IncrementOneValue() throws {
        let options = fixture.options
        options.enableMetrics = true
        let sut = fixture.getSut(options)
        
        sut.metrics.increment(key: "key")
        sut.flush(timeout: 1.0)
        
        let client = self.fixture.client
        expect(client.captureEnvelopeInvocations.count) == 1
        
        let envelope = try XCTUnwrap(client.captureEnvelopeInvocations.first)
        expect(envelope.header.eventId) != nil

        // We only check if it's an envelope with a statsd envelope item.
        // We validate the contents of the envelope in SentryMetricsClientTests
        expect(envelope.items.count) == 1
        let envelopeItem = try XCTUnwrap(envelope.items.first)
        expect(envelopeItem.header.type) == SentryEnvelopeItemTypeStatsd
        expect(envelopeItem.header.contentType) == "application/octet-stream"
    }
    
    func testAddIncrementMetric_GetsLocalMetricsAggregatorFromCurrentSpan() throws {
        let options = fixture.options
        options.enableMetrics = true
        let sut = fixture.getSut(options)
        
        let span = sut.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation, bindToScope: true)
        let tracer = span as! SentryTracer
        
        sut.metrics.increment(key: "key")
        
        let aggregator = tracer.getLocalMetricsAggregator()
        
        let metricsSummary = aggregator.serialize()
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["min"] as? Double) == 1.0
        expect(metric["max"] as? Double) == 1.0
        expect(metric["count"] as? Int) == 1
        expect(metric["sum"] as? Double) == 1.0
    }
    
    func testAddIncrementMetric_AddsDefaultTags() throws {
        let options = fixture.options
        options.releaseName = "release1"
        options.environment = "test"
        options.enableMetrics = true
        let sut = fixture.getSut(options)
        
        let span = sut.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation, bindToScope: true)
        let tracer = span as! SentryTracer
        
        sut.metrics.increment(key: "key", tags: ["my": "tag", "release": "overwritten"])
        
        let aggregator = tracer.getLocalMetricsAggregator()
        
        let metricsSummary = aggregator.serialize()
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["tags"] as? [String: String]) == ["my": "tag", "release": "overwritten", "environment": options.environment]
    }
    
    func testAddIncrementMetric_ReleaseNameNil() throws {
        let options = fixture.options
        options.releaseName = nil
        options.enableMetrics = true
        let sut = fixture.getSut(options)
        
        let span = sut.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation, bindToScope: true)
        let tracer = span as! SentryTracer
        
        sut.metrics.increment(key: "key", tags: ["my": "tag"])
        
        let aggregator = tracer.getLocalMetricsAggregator()
        
        let metricsSummary = aggregator.serialize()
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["tags"] as? [String: String]) == ["my": "tag", "environment": options.environment]
    }
    
    func testAddIncrementMetric_DefaultTagsDisabled() throws {
        let options = fixture.options
        options.releaseName = "release1"
        options.environment = "test"
        options.enableMetrics = true
        options.enableDefaultTagsForMetrics = false
        let sut = fixture.getSut(options)
        
        let span = sut.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation, bindToScope: true)
        let tracer = span as! SentryTracer
        
        sut.metrics.increment(key: "key", tags: ["my": "tag"])
        
        let aggregator = tracer.getLocalMetricsAggregator()
        
        let metricsSummary = aggregator.serialize()
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["tags"] as? [String: String]) == ["my": "tag"]
    }
    
    private func captureEventEnvelope(level: SentryLevel) {
        let event = TestData.event
        event.level = level
        sut.capture(SentryEnvelope(event: event))
    }
    
    private func captureFatalEventWithoutExceptionMechanism() {
        let event = TestData.event
        event.level = SentryLevel.fatal
        event.exceptions?[0].mechanism = nil
        sut.capture(SentryEnvelope(event: event))
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
        return SentryEnvelope(header: SentryEnvelopeHeader(id: event.eventId, traceContext: nil), items: [SentryEnvelopeItem(header: envelopeItem.header, data: eventData)])
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
        XCTAssertFalse(arguments.first?.event.isCrashEvent ?? true)
    }
    
    private func assertCrashEventSent() {
        let arguments = fixture.client.captureCrashEventInvocations
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
        XCTAssertTrue(arguments.first?.event.isCrashEvent ?? false)
    }
    
    private func assertEventSentWithSession(scopeEnvironment: String) {
        let arguments = fixture.client.captureCrashEventWithSessionInvocations
        XCTAssertEqual(1, arguments.count)
        
        let argument = arguments.first
        XCTAssertEqual(fixture.event, argument?.event)
        
        let session = argument?.session
        XCTAssertEqual(fixture.currentDateProvider.date(), session?.timestamp)
        XCTAssertEqual(SentrySessionStatus.crashed, session?.status)
        XCTAssertEqual(fixture.options.environment, session?.environment)
        
        let event = argument?.scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        expect(event?.environment) == scopeEnvironment
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
    
    private func assertSampler(expected: SentrySampleDecision, options: (Options) -> Void) {
        options(fixture.options)
        
        let hub = fixture.getSut()
        let span = hub.startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        
        XCTAssertEqual(expected, span.sampled)
    }
}

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestTimeToDisplayTracker: SentryTimeToDisplayTracker {
    
    init() {
        super.init(for: UIViewController(), waitForFullDisplay: false)
    }
    
    var registerFullDisplayCalled = false
    override func reportFullyDisplayed() {
        registerFullDisplayCalled = true
    }
    
}
#endif
