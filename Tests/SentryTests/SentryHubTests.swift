@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        let sentryCrashWrapper = TestSentryCrashWrapper.sharedInstance()
        let fileManager: SentryFileManager
        let crashedSession: SentrySession
        let abnormalSession: SentrySession
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
            
            abnormalSession = SentrySession(releaseName: "1.0.0", distinctId: "")
            abnormalSession.endAbnormal(withTimestamp: currentDateProvider.date())
            abnormalSession.environment = options.environment
        }
        
        func getSut(withMaxBreadcrumbs maxBreadcrumbs: UInt = 100) -> SentryHub {
            options.maxBreadcrumbs = maxBreadcrumbs
            return getSut(options)
        }
        
        func getSut(_ options: Options, _ scope: Scope? = nil) -> SentryHub {
            let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: sentryCrashWrapper, andDispatchQueue: dispatchQueueWrapper)
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
        fixture.fileManager.deleteAbnormalSession()
        fixture.fileManager.deleteAppState()
        fixture.fileManager.deleteTimestampLastInForeground()
        fixture.fileManager.deleteAllEnvelopes()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAbnormalSession()
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
    
    func testScopeEnriched_WithInitializer() {
        let hub = SentryHub(client: nil, andScope: Scope())
        XCTAssertFalse(hub.scope.contextDictionary.allValues.isEmpty)
        XCTAssertNotNil(hub.scope.contextDictionary["os"])
        XCTAssertNotNil(hub.scope.contextDictionary["device"])
        XCTAssertNotNil(hub.scope.contextDictionary["app"])
    }
    
    func testScopeNotEnriched_WhenScopeIsNil() {
        _ = fixture.getSut()
     
        XCTAssertFalse(fixture.sentryCrashWrapper.enrichScopeCalled)
    }
    
    func testScopeEnriched_WhenCreatingDefaultScope() {
        let hub = SentryHub(client: nil, andScope: nil)
        
        let scope = hub.scope
        XCTAssertFalse(scope.contextDictionary.allValues.isEmpty)
        XCTAssertNotNil(scope.contextDictionary["os"])
        XCTAssertNotNil(scope.contextDictionary["device"])
        XCTAssertNotNil(scope.contextDictionary["app"])
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
    
    func testStartTransactionWithNameOperation() throws {
        let span = fixture.getSut().startTransaction(name: fixture.transactionName, operation: fixture.transactionOperation)
        let tracer = try XCTUnwrap(span as? SentryTracer)
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(span.operation, fixture.transactionOperation)
        XCTAssertEqual(SentryTransactionNameSource.custom, tracer.transactionContext.nameSource)
        XCTAssertEqual("manual", tracer.transactionContext.origin)
    }
    
    func testStartTransactionWithContext() throws {
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(
            name: fixture.transactionName,
            operation: fixture.transactionOperation
        ))
        
        let tracer = try XCTUnwrap(span as? SentryTracer)
        XCTAssertEqual(tracer.transactionContext.name, fixture.transactionName)
        XCTAssertEqual(span.operation, fixture.transactionOperation)
        XCTAssertEqual("manual", tracer.transactionContext.origin)
    }
    
    func testStartTransactionWithNameSource() throws {
        let span = fixture.getSut().startTransaction(transactionContext: TransactionContext(
            name: fixture.transactionName,
            nameSource: .url,
            operation: fixture.transactionOperation,
            origin: fixture.traceOrigin
        ))
        
        let tracer = try XCTUnwrap(span as? SentryTracer)
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
    
    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testCaptureTransaction_CapturesEventAsync() throws {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .yes))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        XCTAssertEqual(self.fixture.client.captureEventWithScopeInvocations.count, 1)
        XCTAssertEqual(self.fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testCaptureTransaction_withSampleRateRand_CapturesEventAsync() throws {
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .yes,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        XCTAssertEqual(self.fixture.client.captureEventWithScopeInvocations.count, 1)
        XCTAssertEqual(self.fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testCaptureSampledTransaction_DoesNotCaptureEvent() throws {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        XCTAssertEqual(self.fixture.client.captureEventWithScopeInvocations.count, 0)
    }
    
    func testCaptureSampledTransaction_withSampleRateRand_DoesNotCaptureEvent() throws {
        // Arrange
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .no,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )
        // Act
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        // Assert
        XCTAssertEqual(self.fixture.client.captureEventWithScopeInvocations.count, 0)
    }
    
    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testCaptureSampledTransaction_RecordsLostEvent() throws {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        XCTAssertEqual(1, fixture.client.recordLostEvents.count)
        let lostEvent = fixture.client.recordLostEvents.first
        XCTAssertEqual(.transaction, lostEvent?.category)
        XCTAssertEqual(.sampleRate, lostEvent?.reason)
    }
    
    func testCaptureSampledTransaction_withSampleRateRand_RecordsLostEvent() throws {
        // Arrange
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .no,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )
        // Act
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        // Assert
        XCTAssertEqual(1, fixture.client.recordLostEvents.count)
        let lostEvent = fixture.client.recordLostEvents.first
        XCTAssertEqual(lostEvent?.category, .transaction)
        XCTAssertEqual(lostEvent?.reason, .sampleRate)
    }
    
    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testCaptureSampledTransaction_RecordsLostSpans() throws {
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        
        if let tracer = transaction as? SentryTracer {
            (trans as? Transaction)?.spans = [
                tracer.startChild(operation: "child1"),
                tracer.startChild(operation: "child2"),
                tracer.startChild(operation: "child3")
            ]
        }
        
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        XCTAssertEqual(1, fixture.client.recordLostEventsWithQauntity.count)
        let lostEvent = fixture.client.recordLostEventsWithQauntity.first
        XCTAssertEqual(.span, lostEvent?.category)
        XCTAssertEqual(.sampleRate, lostEvent?.reason)
        XCTAssertEqual(4, lostEvent?.quantity)
    }

    func testCaptureSampledTransaction_withSampleRateRand_RecordsLostSpans() throws {
        // Arrange
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .no,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )
        // Act
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        
        if let tracer = transaction as? SentryTracer {
            (trans as? Transaction)?.spans = [
                tracer.startChild(operation: "child1"),
                tracer.startChild(operation: "child2"),
                tracer.startChild(operation: "child3")
            ]
        }
        
        sut.capture(try XCTUnwrap(trans as? Transaction), with: Scope())
        
        // Assert
        XCTAssertEqual(1, fixture.client.recordLostEventsWithQauntity.count)
        let lostEvent = fixture.client.recordLostEventsWithQauntity.first
        XCTAssertEqual(lostEvent?.category, .span)
        XCTAssertEqual(lostEvent?.reason, .sampleRate)
        XCTAssertEqual(lostEvent?.quantity, 4)
    }
    
    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testSaveCrashTransaction_SavesTransaction() throws {
        let scope = fixture.scope
        let sut = SentryHub(client: fixture.client, andScope: scope)
        
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .yes))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.saveCrash(try XCTUnwrap(trans as? Transaction))
        
        let client = fixture.client
        XCTAssertEqual(1, client.saveCrashTransactionInvocations.count)
        XCTAssertEqual(scope, client.saveCrashTransactionInvocations.first?.scope)
        XCTAssertEqual(0, client.recordLostEvents.count)
    }
    
    func testSaveCrashTransaction_withSampleRateRand_SavesTransaction() throws {
        // Arrange
        let scope = fixture.scope
        let sut = SentryHub(client: fixture.client, andScope: scope)
        
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .yes,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )

        // Act
        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.saveCrash(try XCTUnwrap(trans as? Transaction))
        
        // Assert
        let client = fixture.client
        XCTAssertEqual(1, client.saveCrashTransactionInvocations.count)
        XCTAssertEqual(scope, client.saveCrashTransactionInvocations.first?.scope)
        XCTAssertEqual(0, client.recordLostEvents.count)
    }
    
    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testSaveCrashTransaction_NotSampled_DoesNotSaveTransaction() throws {
        let scope = fixture.scope
        let sut = SentryHub(client: fixture.client, andScope: scope)
        
        let transaction = sut.startTransaction(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation, sampled: .no))

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.saveCrash(try XCTUnwrap(trans as? Transaction))
        
        XCTAssertEqual(self.fixture.client.saveCrashTransactionInvocations.count, 0)
    }

    func testSaveCrashTransaction_NotSampledWithSampleRateRand_DoesNotSaveTransaction() throws {
        let scope = fixture.scope
        let sut = SentryHub(client: fixture.client, andScope: scope)
        
        let transaction = sut.startTransaction(
            transactionContext: TransactionContext(
                name: fixture.transactionName,
                operation: fixture.transactionOperation,
                sampled: .no,
                sampleRate: 0.123456789,
                sampleRand: 0.987654321
            )
        )

        let trans = Dynamic(transaction).toTransaction().asAnyObject
        sut.saveCrash(try XCTUnwrap(trans as? Transaction))
        
        XCTAssertEqual(self.fixture.client.saveCrashTransactionInvocations.count, 0)
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
    
    func testCaptureFatalEvent_CrashedSessionExists() {
        sut = fixture.getSut(fixture.options, fixture.scope)
        givenCrashedSession()
        
        assertNoCrashedSessionSent()
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        sut.captureFatalEvent(fixture.event)
        assertEventSentWithSession(scopeEnvironment: environment)
        
        // Make sure further crash events are sent
        sut.captureFatalEvent(fixture.event)
        assertFatalEventSent()
    }
    
    func testCaptureFatalEvent_ManualSessionTracking_CrashedSessionExists() {
        givenAutoSessionTrackingDisabled()
        
        givenCrashedSession()
        
        assertNoCrashedSessionSent()
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        sut.captureFatalEvent(fixture.event)
        
        assertEventSentWithSession(scopeEnvironment: environment)
        
        // Make sure further crash events are sent
        sut.captureFatalEvent(fixture.event)
        assertFatalEventSent()
    }
    
    func testCaptureFatalEvent_CrashedSessionDoesNotExist() {
        sut.startSession() // there is already an existing session
        sut.captureFatalEvent(fixture.event)
        
        assertNoCrashedSessionSent()
        assertFatalEventSent()
    }
    
    /**
     * When autoSessionTracking is just enabled and there is a previous crash on the disk there is no session on the disk.
     */
    func testCaptureFatalEvent_CrashExistsButNoSessionExists() {
        sut.captureFatalEvent(fixture.event)
        
        assertFatalEventSent()
    }
    
    func testCaptureFatalEvent_WithoutExistingSessionAndAutoSessionTrackingEnabled() {
        givenAutoSessionTrackingDisabled()
        
        sut.captureFatalEvent(fixture.event)
        
        assertFatalEventSent()
    }
    
    func testCaptureFatalEvent_ClientIsNil() {
        sut = fixture.getSut()
        sut.bindClient(nil)
        
        givenCrashedSession()
        sut.captureFatalEvent(fixture.event)
        
        assertNoEventsSent()
    }
    
    func testCaptureFatalEvent_ClientHasNoReleaseName() {
        sut = fixture.getSut()
        let options = fixture.options
        options.releaseName = nil
        let client = SentryClient(options: options)
        sut.bindClient(client)
        
        givenCrashedSession()
        sut.captureFatalEvent(fixture.event)
        
        assertNoEventsSent()
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testCaptureFatalAppHangEvent_AbnormalSessionExists() {
        // Arrange
        sut = fixture.getSut(fixture.options, fixture.scope)
        givenAbnormalSession()
        
        assertNoAbnormalSessionSent()
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        
        // Act
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertEventSentWithSession(scopeEnvironment: environment, sessionStatus: .abnormal, abnormalMechanism: "anr_foreground")
    }
    
    func testCaptureFatalAppHangEvent_ManualSessionTracking_AbnormalSessionExists() {
        // Arrange
        givenAutoSessionTrackingDisabled()
        givenAbnormalSession()
        assertNoAbnormalSessionSent()
        
        let environment = "test"
        sut.configureScope { $0.setEnvironment(environment) }
        
        // Act
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertEventSentWithSession(scopeEnvironment: environment, sessionStatus: .abnormal, abnormalMechanism: "anr_foreground")
    }
    
    func testCaptureFatalAppHangEvent_AbnormalSessionDoesNotExist() {
        // Arrange
        sut.startSession() // there is already an existing session
        
        // Act
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertNoAbnormalSessionSent()
        assertFatalEventSent()
    }
    
    /**
     * When autoSessionTracking is just enabled and there is a previous fatal app hang on the disk there is no session on the disk.
     */
    func testCaptureFatalAppHangEvent_FatalAppHangExistsButNoSessionExists() {
        // Act
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertFatalEventSent()
    }
    
    func testCaptureFatalAppHangEvent_WithoutExistingSessionAndAutoSessionTrackingEnabled() {
        // Arrange
        givenAutoSessionTrackingDisabled()
        
        // Act
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertFatalEventSent()
    }
    
    func testCaptureFatalAppHangEvent_ClientIsNil() {
        // Arrange
        sut = fixture.getSut()
        sut.bindClient(nil)
        
        // Act
        givenAbnormalSession()
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertNoEventsSent()
    }
    
    func testCaptureFatalAppHangEvent_ClientHasNoReleaseName() {
        // Arrange
        sut = fixture.getSut()
        let options = fixture.options
        options.releaseName = nil
        let client = SentryClient(options: options)
        sut.bindClient(client)
        
        // Act
        givenAbnormalSession()
        sut.captureFatalAppHang(fixture.event)
        
        // Assert
        assertNoEventsSent()
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testCaptureEnvelope_WithEventWithError() throws {
        sut.startSession()
        
        captureEventEnvelope(level: SentryLevel.error)
        
        try assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithoutExceptionMechanism() throws {
        sut.startSession()
        
        try captureFatalEventWithoutExceptionMechanism()
        
        try assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithFatal() throws {
        sut.startSession()
        
        captureEventEnvelope(level: SentryLevel.fatal)
        
        try assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithNoLevel() throws {
        sut.startSession()
        
        let envelope = try givenEnvelopeWithModifiedEvent { eventDict in
            eventDict.removeValue(forKey: "level")
        }
        sut.capture(envelope)
        
        try assertSessionWithIncrementedErrorCountedAdded()
    }
    
    func testCaptureEnvelope_WithEventWithGarbageLevel() throws {
        sut.startSession()
        
        let envelope = try givenEnvelopeWithModifiedEvent { eventDict in
            eventDict["level"] = "Garbage"
        }
        sut.capture(envelope)
        
        try assertSessionWithIncrementedErrorCountedAdded()
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
        
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .buffer, segmentId: 1)
        let replayRecording = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        let videoUrl = URL(string: "https://sentry.io")!
        
        sut.bindClient(mockClient)
        sut.capture(replayEvent, replayRecording: replayRecording, video: videoUrl)
        
        XCTAssertEqual(mockClient?.replayEvent, replayEvent)
        XCTAssertEqual(mockClient?.replayRecording, replayRecording)
        XCTAssertEqual(mockClient?.videoUrl, videoUrl)
        XCTAssertEqual(mockClient?.scope, sut.scope)
    }
    
    func testCaptureEnvelope_WithSession() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "", distinctId: ""))
        sut.capture(envelope)
        
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, fixture.client.captureEnvelopeInvocations.first)
    }
    
    func testCaptureEnvelope_WithUnhandledException() throws {
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
        
        let json = try XCTUnwrap((try! JSONSerialization.jsonObject(with: sessionEnvelopeItem!.data)) as? [String: Any])
        
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
        // -- Arrange --
        let sut = fixture.getSut(fixture.options)
        
        let testTTDTracker = TestTimeToDisplayTracker(waitForFullDisplay: true)
        
        let performanceTracker = Dynamic(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
        performanceTracker.currentTTDTracker = testTTDTracker

        // -- Act --
        sut.reportFullyDisplayed()
        
        // -- Assert --
        XCTAssertTrue(testTTDTracker.registerFullDisplayCalled)
    }
    
    func test_reportFullyDisplayed_enableTimeToFullDisplay_NO() {
        // -- Arrange --
        let sut = fixture.getSut(fixture.options)
        
        let testTTDTracker = TestTimeToDisplayTracker(waitForFullDisplay: false)
        
        let performanceTracker = Dynamic(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
        performanceTracker.currentTTDTracker = testTTDTracker
        
        // -- Act --
        sut.reportFullyDisplayed()
        
        // -- Assert --
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
                    XCTAssertNotNil(sut.getInstalledIntegration(EmptyIntegration.self))
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
                    sut.getInstalledIntegration(EmptyIntegration.self)
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
    
    func testGetInstalledIntegration() {
        let integration = EmptyIntegration()
        sut.addInstalledIntegration(integration, name: "EmptyIntegration")
        
        let installedIntegration = sut.getInstalledIntegration(EmptyIntegration.self)
        
        XCTAssert(integration === installedIntegration)
    }
    
    func testGetInstalledIntegration_ReturnsNilIfNotFound() {
        let integration = EmptyIntegration()
        sut.addInstalledIntegration(integration, name: "EmptyIntegration")
        
        XCTAssertNil(sut.getInstalledIntegration(SentryANRTrackingIntegration.self))
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
    
    private func captureEventEnvelope(level: SentryLevel) {
        let event = TestData.event
        event.level = level
        sut.capture(SentryEnvelope(event: event))
    }
    
    private func captureFatalEventWithoutExceptionMechanism() throws {
        let event = TestData.event
        event.level = SentryLevel.fatal
        try XCTUnwrap(event.exceptions?.first).mechanism = nil
        sut.capture(SentryEnvelope(event: event))
    }
    
    private func givenCrashedSession() {
        fixture.sentryCrashWrapper.internalCrashedLastLaunch = true
        fixture.fileManager.storeCrashedSession(fixture.crashedSession)
        sut.closeCachedSession(withTimestamp: fixture.currentDateProvider.date())
        sut.startSession()
    }
    
    private func givenAbnormalSession() {
        fixture.fileManager.storeAbnormalSession(fixture.abnormalSession)
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
        var eventDict = try XCTUnwrap(JSONSerialization.jsonObject(with: envelopeItem.data) as? [String: Any])
        
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
    
    private func assertNoAbnormalSessionSent() {
        XCTAssertFalse(fixture.client.captureSessionInvocations.invocations.contains(where: { session in
            return session.status == SentrySessionStatus.abnormal
        }))
    }
    
    private func assertNoEventsSent() {
        XCTAssertEqual(0, fixture.client.captureEventInvocations.count)
        XCTAssertEqual(0, fixture.client.captureFatalEventWithSessionInvocations.count)
        XCTAssertEqual(0, fixture.client.captureFatalEventInvocations.count)
    }
    
    private func assertEventSent() {
        let arguments = fixture.client.captureEventWithScopeInvocations
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
        XCTAssertFalse(arguments.first?.event.isFatalEvent ?? true)
    }
    
    private func assertFatalEventSent() {
        let arguments = fixture.client.captureFatalEventInvocations
        XCTAssertEqual(1, arguments.count)
        XCTAssertEqual(fixture.event, arguments.first?.event)
        XCTAssertTrue(arguments.first?.event.isFatalEvent ?? false)
    }
    
    private func assertEventSentWithSession(scopeEnvironment: String, sessionStatus: SentrySessionStatus = .crashed, abnormalMechanism: String? = nil) {
        let arguments = fixture.client.captureFatalEventWithSessionInvocations
        XCTAssertEqual(1, arguments.count)
        
        let argument = arguments.first
        XCTAssertEqual(fixture.event, argument?.event)
        
        let session = argument?.session
        XCTAssertEqual(fixture.currentDateProvider.date(), session?.timestamp)
        XCTAssertEqual(sessionStatus, session?.status)
        XCTAssertEqual(abnormalMechanism, session?.abnormalMechanism)
        XCTAssertEqual(fixture.options.environment, session?.environment)
    }
    
    private func assertSessionWithIncrementedErrorCountedAdded() throws {
        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        let envelope = fixture.client.captureEnvelopeInvocations.first!
        XCTAssertEqual(2, envelope.items.count)
        let session = SentrySerialization.session(with: try XCTUnwrap(envelope.items.element(at: 1)).data)
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
    
    init(waitForFullDisplay: Bool = false) {
        super.init(name: "UIViewController", waitForFullDisplay: waitForFullDisplay, dispatchQueueWrapper: SentryDispatchQueueWrapper())
    }
    
    var registerFullDisplayCalled = false
    override func reportFullyDisplayed() {
        registerFullDisplayCalled = true
    }
    
}
#endif
