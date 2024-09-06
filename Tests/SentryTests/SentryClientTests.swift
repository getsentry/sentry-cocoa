@testable import Sentry
import SentryTestUtils
import XCTest

// swiftlint:disable file_length
// We are aware that the client has a lot of logic and we should maybe
// move some of it to other classes.
class SentryClientTest: XCTestCase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryClientTest")

    private class Fixture {
        let transport: TestTransport
        let transportAdapter: TestTransportAdapter
        
        let debugImageBuilder = SentryDebugImageProvider()
        let threadInspector = TestThreadInspector.instance
        
        let session: SentrySession
        let event: Event
        let environment = "Environment"
        let messageAsString = "message"
        let message: SentryMessage
        
        let user: User
        let fileManager: SentryFileManager
        let random = TestRandom(value: 1.0)
        
        let trace = SentryTracer(transactionContext: TransactionContext(name: "SomeTransaction", operation: "SomeOperation"), hub: nil)
        let transaction: Transaction
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
        #if os(iOS) || targetEnvironment(macCatalyst)
        let deviceWrapper = TestSentryUIDeviceWrapper()
        #endif // os(iOS) || targetEnvironment(macCatalyst)
        let processWrapper = TestSentryNSProcessInfoWrapper()
        let extraContentProvider: SentryExtraContextProvider
        let locale = Locale(identifier: "en_US")
        let timezone = TimeZone(identifier: "Europe/Vienna")!
        let queue = DispatchQueue(label: "SentryHubTests", qos: .utility, attributes: [.concurrent])
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        init() throws {
            session = SentrySession(releaseName: "release", distinctId: "some-id")
            session.incrementErrors()

            message = SentryMessage(formatted: messageAsString)

            event = Event()
            event.message = message
            
            user = User()
            user.email = "someone@sentry.io"
            user.ipAddress = "127.0.0.1"
            
            let options = Options()
            options.dsn = SentryClientTest.dsn
            fileManager = try XCTUnwrap(SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
            
            transaction = Transaction(trace: trace, children: [])
            
            transport = TestTransport()
            transportAdapter = TestTransportAdapter(transports: [transport], options: options)
            
            crashWrapper.internalFreeMemorySize = 123_456
            crashWrapper.internalAppMemorySize = 234_567

            #if os(iOS) || targetEnvironment(macCatalyst)
            SentryDependencyContainer.sharedInstance().uiDeviceWrapper = deviceWrapper
#endif // os(iOS) || targetEnvironment(macCatalyst)
            
            extraContentProvider = SentryExtraContextProvider(crashWrapper: crashWrapper, processInfoWrapper: processWrapper)
            SentryDependencyContainer.sharedInstance().extraContextProvider = extraContentProvider
        }

        func getSut(configureOptions: (Options) -> Void = { _ in }) -> SentryClient {
            var client: SentryClient!
            do {
                let options = try Options(dict: [
                    "dsn": SentryClientTest.dsn
                ])
                options.removeAllIntegrations()
                configureOptions(options)

                client = SentryClient(
                    options: options,
                    transportAdapter: transportAdapter,
                    fileManager: fileManager,
                    deleteOldEnvelopeItems: false,
                    threadInspector: threadInspector,
                    random: random,
                    locale: locale,
                    timezone: timezone
                )
            } catch {
                XCTFail("Options could not be created")
            }

            return client
        }

        func getSutWithNoDsn() -> SentryClient {
            getSut(configureOptions: { options in
                options.parsedDsn = nil
            })
        }
        
        func getSutDisabledSdk() -> SentryClient {
            getSut(configureOptions: { options in
                options.enabled = false
            })
        }

        var scope: Scope {
            let scope = Scope()
            scope.setEnvironment(environment)
            scope.setTag(value: "value", key: "key")
            scope.addAttachment(TestData.dataAttachment)
            scope.setContext(value: [SentryDeviceContextFreeMemoryKey: 2_000], key: "device")
            return scope
        }
        
        var eventWithCrash: Event {
            let event = TestData.event
            let exception = Exception(value: "value", type: "type")
            let mechanism = Mechanism(type: "mechanism")
            mechanism.handled = false
            exception.mechanism = mechanism
            event.exceptions = [exception]
            return event
        }
    }

    private let error = NSError(domain: "domain", code: -20, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])

    private let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        fixture.fileManager.deleteAllEnvelopes()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInit_CallsDeleteOldEnvelopeItemsInvocations() throws {
        let fileManager = try TestFileManager(options: Options())
        
        _ = SentryClient(options: Options(), fileManager: fileManager, deleteOldEnvelopeItems: true)
        
        XCTAssertEqual(1, fileManager.deleteOldEnvelopeItemsInvocations.count)
    }
    
    func testInitCachesInstallationIDAsync() throws {
        let dispatchQueue = fixture.dispatchQueue
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = fixture.dispatchQueue
        
        let options = Options()
        options.dsn = SentryClientTest.dsn
        // We have to put our cache into a subfolder of the default path, because on macOS we can't delete the default cache folder
        options.cacheDirectoryPath = "\(options.cacheDirectoryPath)/cache"
        _ = SentryClient(options: options)
        
        XCTAssertEqual(dispatchQueue.dispatchAsyncInvocations.count, 1)
        
        let nonCachedID = SentryInstallation.id(withCacheDirectoryPathNonCached: options.cacheDirectoryPath)
        
        // We remove the file containing the installation ID, but the cached ID is still in memory
        try FileManager().removeItem(atPath: options.cacheDirectoryPath)
        
        let cachedID = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
        
        XCTAssertEqual(cachedID, nonCachedID)
    }
    
    func testClientIsEnabled() {
        XCTAssertTrue(fixture.getSut().isEnabled)
    }
    
    func testCaptureMessage() throws {
        let eventId = fixture.getSut().capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(SentryLevel.info, actual.level)
        XCTAssertEqual(fixture.message, actual.message)

        assertValidDebugMeta(actual: actual.debugMeta, forThreads: actual.threads)
        assertValidThreads(actual: actual.threads)
    }

    func testCaptureMessageWithoutStacktrace() throws {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(SentryLevel.info, actual.level)
        XCTAssertEqual(fixture.message, actual.message)
        XCTAssertNil(actual.debugMeta)
        XCTAssertNil(actual.threads)
        XCTAssertNotNil(actual.dist)
    }
    
    func testCaptureEvent() throws {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        let scope = Scope()
        let expectedTags = ["tagKey": "tagValue"]
        scope.setTags(expectedTags)
        
        let eventId = fixture.getSut().capture(event: event, scope: scope)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(event.level, actual.level)
        XCTAssertEqual(event.message, actual.message)
        XCTAssertNotNil(actual.debugMeta)
        XCTAssertNotNil(actual.threads)
        
        XCTAssertNotNil(actual.tags)
        if let actualTags = actual.tags {
            XCTAssertEqual(expectedTags, actualTags)
        }
    }
    
    func testCaptureEventWithScope_SerializedTagsAndExtraShouldMatch() throws {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        let scope = Scope()
        let expectedTags = ["tagKey": "tagValue"]
        let expectedExtra = ["extraKey": "extraValue"]
        scope.setTags(expectedTags)
        scope.setExtras(expectedExtra)
        
        let eventId = fixture.getSut().capture(event: event, scope: scope)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        let serializedEvent = actual.serialize()
        let tags = try XCTUnwrap(serializedEvent["tags"] as? [String: String])
        let extra = try XCTUnwrap(serializedEvent["extra"] as? [String: String])
        XCTAssertEqual(expectedTags, tags)
        XCTAssertEqual(expectedExtra, extra)
    }
        
    func testCaptureEventTypeTransactionDoesNotIncludeThreadAndDebugMeta() throws {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        event.type = SentryEnvelopeItemTypeTransaction
        let scope = Scope()
        let expectedTags = ["tagKey": "tagValue"]
        scope.setTags(expectedTags)
        
        let eventId = fixture.getSut().capture(event: event, scope: scope)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(event.level, actual.level)
        XCTAssertEqual(event.message, actual.message)
        XCTAssertNil(actual.debugMeta)
        XCTAssertNil(actual.threads)
        
        XCTAssertNotNil(actual.tags)
        if let actualTags = actual.tags {
            XCTAssertEqual(expectedTags, actualTags)
        }
    }
      
    func testCaptureEventWithException() throws {
        let event = Event()
        event.exceptions = [ Exception(value: "", type: "")]
        
        fixture.getSut().capture(event: event, scope: fixture.scope)
        
        let actual = try lastSentEventWithAttachment()
        assertValidDebugMeta(actual: actual.debugMeta, forThreads: event.threads)
        assertValidThreads(actual: actual.threads)
    }

    func testCaptureEventWithNoDsn() {
        let event = Event()

        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).capture(event: event)
        
        eventId.assertIsEmpty()
    }
    
#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
    func testCaptureEventWithCurrentScreen() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        
        let event = Event()
        event.exceptions = [ Exception(value: "", type: "")]
        
        fixture.getSut().capture(event: event, scope: fixture.scope)
        
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertEqual(viewName?.first, "ClientTestViewController")
    }

    func testCaptureEventWithCurrentScreenInTheScope() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        
        let event = Event()
        event.exceptions = [ Exception(value: "", type: "")]
        
        let scope = fixture.scope
        scope.currentScreen = "TestScreen"
        
        fixture.getSut().capture(event: event, scope: scope)
        
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertEqual(viewName?.first, "TestScreen")
    }
    
    func testCaptureEventWithNoCurrentScreenMainIsLocked() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        
        let event = Event()
        event.exceptions = [ Exception(value: "", type: "")]
        
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            self.fixture.getSut().capture(event: event, scope: self.fixture.scope)
            group.leave()
        }
        group.enter()
        let _ = group.wait(timeout: .now() + 1)
        
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertNil(viewName)
    }
    
    func testCaptureTransactionWithScreen() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        let tracer = SentryTracer(transactionContext: TransactionContext(operation: "Operation"), hub: nil)
        let event = try XCTUnwrap(Dynamic(tracer).toTransaction() as Transaction?)
        fixture.getSut().capture(event: event, scope: fixture.scope)
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertEqual(viewName?.first, "ClientTestViewController")
    }
    
    func testCaptureTransactionWithScreenInScope() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        let scope = fixture.scope
        scope.currentScreen = "TransactionScreen"
        let hub = SentryHub(client: SentryClient(options: Options()), andScope: scope)
        
        let tracer = SentryTracer(transactionContext: TransactionContext(operation: "Operation"), hub: hub)
        
        scope.currentScreen = "SecondScreen"
        let event = try XCTUnwrap(Dynamic(tracer).toTransaction() as Transaction?, "Could not get transaction from tracer")
        fixture.getSut().capture(event: event, scope: scope)
        
        let lastEvent = try lastSentEventWithAttachment()
        let viewName = lastEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertEqual(viewName?.first, "TransactionScreen")
    }
    
    func testCaptureTransactionWithChangeScreen() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        let tracer = SentryTracer(transactionContext: TransactionContext(operation: "Operation"), hub: nil)
        let event = try XCTUnwrap(Dynamic(tracer).toTransaction() as Transaction?)
        event.viewNames = ["AnotherScreen"]
        fixture.getSut().capture(event: event, scope: fixture.scope)
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertEqual(viewName?.first, "AnotherScreen")
    }
    
    func testCaptureTransactionWithoutScreen() throws {
        SentryDependencyContainer.sharedInstance().application = TestSentryUIApplication()
        
        let event = Transaction(trace: SentryTracer(context: SpanContext(operation: "test"), framesTracker: nil), children: [])
        fixture.getSut().capture(event: event, scope: fixture.scope)
        
        let sentEvent = try lastSentEventWithAttachment()
        let viewName = sentEvent.context?["app"]?["view_names"] as? [String]
        XCTAssertNil(viewName)
    }
#endif
    
    func test_AttachmentProcessor_CaptureEvent() {
        let sut = fixture.getSut()
        let event = Event()
        let extraAttachment = Attachment(data: Data(), filename: "ExtraAttachment")

        let expectProcessorCall = expectation(description: "Processor Call")
        let processor = TestAttachmentProcessor { atts, e in
            var result = atts ?? []
            result.append(extraAttachment)
            XCTAssertEqual(event, e)
            expectProcessorCall.fulfill()
            return result
        }
        
        sut.add(processor)
        sut.capture(event: event)
        
        let sentAttachments = fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.attachments ?? []
        
        wait(for: [expectProcessorCall], timeout: 1)
        XCTAssertEqual(sentAttachments.count, 1)
        XCTAssertEqual(extraAttachment, sentAttachments.first)
    }
    
    func test_AttachmentProcessor_CaptureError_WithSession() {
        let sut = fixture.getSut()
        let error = NSError(domain: "test", code: -1)
        let extraAttachment = Attachment(data: Data(), filename: "ExtraAttachment")

        let processor = TestAttachmentProcessor { atts, _ in
            var result = atts ?? []
            result.append(extraAttachment)
            return result
        }

        sut.add(processor)
        sut.captureError(error, with: Scope()) {
            self.fixture.session
        }

        let sentAttachments = fixture.transportAdapter.sentEventsWithSessionTraceState.first?.attachments ?? []

        XCTAssertEqual(sentAttachments.count, 1)
        XCTAssertEqual(extraAttachment, sentAttachments.first)
    }
    
    func test_AttachmentProcessor_CaptureError_WithSession_NoReleaseName() {
        let sut = fixture.getSut()
        let error = NSError(domain: "test", code: -1)
        let extraAttachment = Attachment(data: Data(), filename: "ExtraAttachment")
        
        let processor = TestAttachmentProcessor { atts, _ in
            var result = atts ?? []
            result.append(extraAttachment)
            return result
        }
        
        sut.add(processor)
        sut.captureError(error, with: Scope()) {
            return SentrySession(releaseName: "", distinctId: "some-id")
        }
        
        let sentAttachments = fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.attachments ?? []
        
        XCTAssertEqual(sentAttachments.count, 1)
        XCTAssertEqual(extraAttachment, sentAttachments.first)
    }
    
    func testCaptureEventWithDsnSetAfterwards() {
        let event = Event()

        let sut = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        })
        
        sut.options.dsn = SentryClientTest.dsn
        
        let eventId = sut.capture(event: event)
        eventId.assertIsNotEmpty()
    }
    
    func testCaptureEventWithDebugMeta_KeepsDebugMeta() throws {
        let sut = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        })
        
        let event = givenEventWithDebugMeta()
        sut.capture(event: event)
        
        let actual = try lastSentEvent()
        XCTAssertEqual(event.debugMeta, actual.debugMeta)
        assertValidThreads(actual: actual.threads)
    }
    
    func testCaptureEventWithAttachedThreads_KeepsThreads() throws {
        let sut = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        })
        
        let event = givenEventWithThreads()
        sut.capture(event: event)
        
        let actual = try lastSentEvent()
        assertValidDebugMeta(actual: actual.debugMeta, forThreads: event.threads)
        XCTAssertEqual(event.threads, actual.threads)
    }
    
    func testCaptureEventWithAttachStacktrace() throws {
        let event = Event(level: SentryLevel.fatal)
        event.message = fixture.message
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        }).capture(event: event)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(event.level, actual.level)
        XCTAssertEqual(event.message, actual.message)
        assertValidDebugMeta(actual: actual.debugMeta, forThreads: event.threads)
        assertValidThreads(actual: event.threads)
    }
    
    func testCaptureErrorWithoutAttachStacktrace() throws {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(error: error, scope: fixture.scope)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEventWithAttachment()
        try assertValidErrorEvent(actual, error)
    }
    
    func testCaptureErrorWithEnum() throws {
        let eventId = fixture.getSut().capture(error: TestError.invalidTest)

        eventId.assertIsNotEmpty()
        let error = TestError.invalidTest as NSError
        let actual = try lastSentEvent()
        try assertValidErrorEvent(actual, error, exceptionValue: "invalidTest (Code: 0)")
    }

    func testCaptureErrorUsesErrorDebugDescriptionWhenSet() throws {
        let error = NSError(
            domain: "com.sentry",
            code: 999,
            userInfo: [NSDebugDescriptionErrorKey: "Custom error description"]
        )
        let eventId = fixture.getSut().capture(error: error)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        let exceptions = try XCTUnwrap(actual.exceptions)
        XCTAssertEqual("Custom error description (Code: 999)", try XCTUnwrap(exceptions.first).value)
    }

    func testCaptureErrorUsesErrorCodeAsDescriptionIfNoCustomDescriptionProvided() throws {
        let error = NSError(
            domain: "com.sentry",
            code: 999,
            userInfo: [:]
        )
        let eventId = fixture.getSut().capture(error: error)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        do {
            let exceptions = try XCTUnwrap(actual.exceptions)
            XCTAssertEqual("Code: 999", try XCTUnwrap(exceptions.first).value)
        } catch {
            XCTFail("Exception expected but was nil")
        }
    }
    
    func testCaptureSwiftError_UsesSwiftStringDescription() throws {
        let eventId = fixture.getSut().capture(error: SentryClientError.someError)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        do {
            let exceptions = try XCTUnwrap(actual.exceptions)
            XCTAssertEqual("someError (Code: 1)", try XCTUnwrap(exceptions.first).value)
        } catch {
            XCTFail("Exception expected but was nil")
        }
    }
    
    func testCaptureSwiftErrorStruct_UsesSwiftStringDescription() throws {
        let eventId = fixture.getSut().capture(error: XMLParsingError(line: 10, column: 12, kind: .internalError))

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        do {
            let exceptions = try XCTUnwrap(actual.exceptions)
            XCTAssertEqual("XMLParsingError(line: 10, column: 12, kind: SentryTests.XMLParsingError.ErrorKind.internalError) (Code: 1)", try XCTUnwrap(exceptions.first).value)
        } catch {
            XCTFail("Exception expected but was nil")
        }
    }
    
    func testCaptureSwiftErrorWithData_UsesSwiftStringDescription() throws {
        let eventId = fixture.getSut().capture(error: SentryClientError.invalidInput("hello"))

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        do {
            let exceptions = try XCTUnwrap(actual.exceptions)
            XCTAssertEqual("invalidInput(\"hello\") (Code: 0)", try XCTUnwrap(exceptions.first).value)
        } catch {
            XCTFail("Exception expected but was nil")
        }
    }
    
    func testCaptureSwiftErrorWithDebugDescription_UsesDebugDescription() throws {
        let eventId = fixture.getSut().capture(error: SentryClientErrorWithDebugDescription.someError)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        do {
            let exceptions = try XCTUnwrap(actual.exceptions)
            XCTAssertEqual("anotherError (Code: 0)", try XCTUnwrap(exceptions.first).value)
        } catch {
            XCTFail("Exception expected but was nil")
        }
    }

    func testCaptureErrorWithComplexUserInfo() throws {
        let url = URL(string: "https://github.com/getsentry")!
        let error = NSError(domain: "domain", code: 0, userInfo: ["url": url])
        let eventId = fixture.getSut().capture(error: error, scope: fixture.scope)

        eventId.assertIsNotEmpty()

        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual(url.absoluteString, actual.context!["user info"]!["url"] as? String)
    }
    
    func testCaptureErrorWithNestedUnderlyingErrors() throws {
        let error = NSError(domain: "domain1", code: 100, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: "domain2", code: 101, userInfo: [
                NSUnderlyingErrorKey: NSError(domain: "domain3", code: 102)
            ])
        ])
        
        fixture.getSut().capture(error: error)
        
        let lastSentEventArguments = try XCTUnwrap(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions).count, 3)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.first?.mechanism?.meta?.error).code, 102)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.last?.mechanism?.meta?.error).code, 100)
    }
    
    func testCaptureErrorWithInvalidUnderlyingError() throws {
        let error = NSError(domain: "domain", code: 100, userInfo: [
            NSUnderlyingErrorKey: "garbage"
        ])
        
        fixture.getSut().capture(error: error)
        
        let lastSentEventArguments = try XCTUnwrap(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions).count, 1)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.first?.mechanism?.meta?.error).code, 100)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.last?.mechanism?.meta?.error).code, 100)
    }
    
    func testCaptureErrorWithNestedInvalidUnderlyingError() throws {
        let error = NSError(domain: "domain1", code: 100, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: "domain2", code: 101, userInfo: [
                NSUnderlyingErrorKey: "More garbage"
            ])
        ])
        
        fixture.getSut().capture(error: error)
        
        let lastSentEventArguments = try XCTUnwrap(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions).count, 2)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.first?.mechanism?.meta?.error).code, 101)
        XCTAssertEqual(try XCTUnwrap(lastSentEventArguments.event.exceptions?.last?.mechanism?.meta?.error).code, 100)
    }

    func testCaptureErrorWithSession() throws {
        let sessionBlockExpectation = expectation(description: "session block gets called")
        let scope = Scope()
        let eventId = fixture.getSut().captureError(error, with: scope) {
            sessionBlockExpectation.fulfill()
            return self.fixture.session
        }
        wait(for: [sessionBlockExpectation], timeout: 0.2)

        eventId.assertIsNotEmpty()
        XCTAssertNotNil(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        if let eventWithSessionArguments = fixture.transportAdapter.sentEventsWithSessionTraceState.last {
            try assertValidErrorEvent(eventWithSessionArguments.event, error)
            XCTAssertEqual(fixture.session, eventWithSessionArguments.session)
            
            let expectedTraceContext = TraceContext(trace: scope.propagationContext.traceId, options: Options(), userSegment: "segment", replayId: nil) 
            XCTAssertEqual(eventWithSessionArguments.traceContext?.traceId,
                           expectedTraceContext.traceId)
        }
    }
    
    func testCaptureErrorWithSession_WithBeforeSendReturnsNil() throws {
        let sessionBlockExpectation = expectation(description: "session block does not get called")
        sessionBlockExpectation.isInverted = true

        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in return nil }
        }).captureError(error, with: Scope()) {
            // This should NOT be called
            sessionBlockExpectation.fulfill()
            return self.fixture.session
        }
        wait(for: [sessionBlockExpectation], timeout: 0.2)
        
        eventId.assertIsEmpty()
    }

    func testCaptureCrashEventWithSession() throws {
        let eventId = fixture.getSut().captureCrash(fixture.event, with: fixture.session, with: fixture.scope)

        eventId.assertIsNotEmpty()
        
        XCTAssertNotNil(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        let args = try XCTUnwrap(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        XCTAssertEqual(fixture.event.eventId, args.event.eventId)
        XCTAssertEqual(fixture.event.message, args.event.message)
        XCTAssertEqual("value", args.event.tags?["key"] ?? "")
        XCTAssertEqual(fixture.session, args.session)
    }
    
    func testCaptureCrashWithSession_DoesntOverideStacktrace() throws {
        let event = TestData.event
        event.threads = nil
        event.debugMeta = nil
        
        fixture.getSut().captureCrash(event, with: fixture.session, with: fixture.scope)
        
        XCTAssertNotNil(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        let args = try XCTUnwrap(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        XCTAssertNil(args.event.threads)
        XCTAssertNil(args.event.debugMeta)
    }
    
    func testCaptureCrashEvent() throws {
        let eventId = fixture.getSut().captureCrash(fixture.event, with: fixture.scope)

        eventId.assertIsNotEmpty()
        
        let event = try lastSentEventWithAttachment()
        XCTAssertEqual(fixture.event.eventId, event.eventId)
        XCTAssertEqual(fixture.event.message, event.message)
        XCTAssertEqual("value", event.tags?["key"] ?? "")
    }
    
    func testCaptureOOMEvent_RemovesMutableInfoFromDeviceContext() throws {
        let oomEvent = TestData.oomEvent
        
        _ = fixture.getSut().captureCrash(oomEvent, with: fixture.scope)

        let event = try lastSentEventWithAttachment()
        XCTAssertEqual(oomEvent.eventId, event.eventId)

        let deviceContext = try XCTUnwrap(event.context?["device"] as? [String: Any])
        XCTAssertEqual(deviceContext.count, 0)
    }
    
    func testCaptureOOMEvent_WithNoContext_ContextNotModified() throws {
        let oomEvent = TestData.oomEvent
        
        _ = fixture.getSut().captureCrash(oomEvent, with: Scope())

        let actual = try lastSentEvent()
        XCTAssertEqual(oomEvent.eventId, actual.eventId)
        XCTAssertEqual(oomEvent.context?.count, actual.context?.count)
    }
    
    func testCaptureOOMEvent_WithNoDeviceContext_ContextNotModified() throws {
        let oomEvent = TestData.oomEvent
        let scope = Scope()
        scope.setContext(value: ["some": "thing"], key: "any")
        
        _ = fixture.getSut().captureCrash(oomEvent, with: scope)

        let actual = try lastSentEvent()
        XCTAssertEqual(oomEvent.eventId, actual.eventId)
        XCTAssertEqual(oomEvent.context?.count, actual.context?.count)
    }
    
    func testCaptureCrash_DoesntOverideStacktraceFor() throws {
        let event = TestData.event
        event.threads = nil
        event.debugMeta = nil
        
        fixture.getSut().captureCrash(event, with: fixture.scope)
        
        let actual = try lastSentEventWithAttachment()
        XCTAssertNil(actual.threads)
        XCTAssertNil(actual.debugMeta)
    }
    
    func testCaptureCrash_NoExtraContext() throws {
        let event = TestData.event

        fixture.getSut().captureCrash(event, with: fixture.scope)

        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual(1, actual.context?["device"]?.count, "The device context should only contain free_memory")
        
        let eventFreeMemory = actual.context?["device"]?[SentryDeviceContextFreeMemoryKey] as? Int
        XCTAssertEqual(eventFreeMemory, 2_000)
        
        XCTAssertNil(actual.context?["app"], "The app context should be nil")
        XCTAssertNil(actual.context?["culture"], "The culture context should be nil")
    }

    func testCaptureEvent_AddCurrentMemoryStorageAndCPUCoreCount() throws {

        let sut = fixture.getSut()
        fixture.processWrapper.overrides.processorCount = 12

        sut.capture(event: TestData.event)

        let actual = try lastSentEvent()
        let eventFreeMemory = actual.context?["device"]?[SentryDeviceContextFreeMemoryKey] as? Int
        XCTAssertEqual(eventFreeMemory, 123_456)

        let eventAppMemory = actual.context?["app"]?["app_memory"] as? Int
        XCTAssertEqual(eventAppMemory, 234_567)

        let cpuCoreCount = actual.context?["device"]?["processor_count"] as? UInt
        XCTAssertEqual(fixture.processWrapper.processorCount, cpuCoreCount)
    }
    
#if os(iOS) || targetEnvironment(macCatalyst)
    func testCaptureEvent_DeviceProperties() throws {
        fixture.getSut().capture(event: TestData.event)

        let actual = try lastSentEvent()
        let deviceContext = try XCTUnwrap(actual.context?["device"] as? [String: Any])
        let orientation = try XCTUnwrap(deviceContext["orientation"] as? String)
        XCTAssertEqual(orientation, "portrait")

        let charging = try XCTUnwrap(deviceContext["charging"] as? Bool)
        XCTAssertEqual(charging, true)

        let batteryLevel = try XCTUnwrap(deviceContext["battery_level"] as? Int)
        XCTAssertEqual(batteryLevel, 60)

        let thermalState = try XCTUnwrap(deviceContext["thermal_state"] as? String)
        XCTAssertEqual(thermalState, "nominal")
    }

    func testCaptureEvent_DeviceProperties_OtherValues() throws {
        fixture.deviceWrapper.internalOrientation = .landscapeLeft
        fixture.deviceWrapper.internalBatteryState = .full

        fixture.getSut().capture(event: TestData.event)

        let actual = try lastSentEvent()
        let orientation = actual.context?["device"]?["orientation"] as? String
        XCTAssertEqual(orientation, "landscape")

        let charging = try XCTUnwrap(actual.context?["device"]?["charging"] as? Bool)
        XCTAssertFalse(charging)
    }
#endif

    func testCaptureEvent_AddCurrentCulture() throws {
        fixture.getSut().capture(event: TestData.event)

        let actual = try lastSentEvent()
        let culture = actual.context?["culture"]
        
        if #available(iOS 10, macOS 10.12, watchOS 3, tvOS 10, *) {
            let expectedCalendar = fixture.locale.localizedString(for: fixture.locale.calendar.identifier)
            XCTAssertEqual(culture?["calendar"] as? String, expectedCalendar)
            XCTAssertEqual(culture?["display_name"] as? String, fixture.locale.localizedString(forIdentifier: fixture.locale.identifier))
        }
            
        XCTAssertEqual(culture?["locale"] as? String, fixture.locale.identifier)
        XCTAssertEqual(culture?["is_24_hour_format"] as? Bool, SentryLocale.timeIs24HourFormat())
        XCTAssertEqual(culture?["timezone"] as? String, fixture.timezone.identifier)
    }

    func testCaptureErrorWithUserInfo() throws {
        let expectedValue = "val"
        let error = NSError(domain: "domain", code: 0, userInfo: ["key": expectedValue])
        let eventId = fixture.getSut().capture(error: error,

 scope: fixture.scope)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(expectedValue, actual.context?["user info"]?["key"] as? String)
    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testCaptureExceptionWithAppStateInForegroudWhenAppIsInForeground() throws {
        let app = TestSentryUIApplication()
        app.applicationState = .active
        SentryDependencyContainer.sharedInstance().application = app
        
        let event = TestData.event
        fixture.getSut().capture(event: event)
        let actual = try lastSentEvent()
        let inForeground = actual.context?["app"]?["in_foreground"] as? Bool
        XCTAssertEqual(inForeground, true)
    }

    func testCaptureExceptionWithAppStateInForegroudWhenAppIsInBackground() throws {
        let app = TestSentryUIApplication()
        app.applicationState = .background
        SentryDependencyContainer.sharedInstance().application = app
        
        let event = TestData.event
        fixture.getSut().capture(event: event)
        let actual = try lastSentEvent()
        let inForeground = try XCTUnwrap(actual.context?["app"]?["in_foreground"] as? Bool)
        XCTAssertFalse(inForeground)
    }
    
    func testCaptureExceptionWithAppStateInForegroudWhenAppIsInactive() throws {
        let app = TestSentryUIApplication()
        app.applicationState = .inactive
        SentryDependencyContainer.sharedInstance().application = app
        
        let event = TestData.event
        fixture.getSut().capture(event: event)
        let actual = try lastSentEvent()
        let inForeground = try XCTUnwrap(actual.context?["app"]?["in_foreground"] as? Bool)
        XCTAssertFalse(inForeground)
    }
    
    func testCaptureExceptionWithAppStateInForegroundDoNotOverwriteExistingValue() throws {
        let app = TestSentryUIApplication()
        app.applicationState = .active
        SentryDependencyContainer.sharedInstance().application = app
        
        let event = TestData.event
        event.context?["app"] = ["in_foreground": "keep-value"]
        fixture.getSut().capture(event: event)
        let actual = try lastSentEvent()
        let inForeground = try XCTUnwrap(actual.context?["app"]?["in_foreground"] as? String)
        XCTAssertEqual(inForeground, "keep-value")
    }
#endif

    func testCaptureExceptionWithoutAttachStacktrace() throws {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(exception: exception, scope: fixture.scope)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEventWithAttachment()
        assertValidExceptionEvent(actual)
    }
    
    func testCaptureExceptionWithSession() {
        let eventId = fixture.getSut().capture(exception, with: fixture.scope) {
            self.fixture.session
        }

        eventId.assertIsNotEmpty()
        XCTAssertNotNil(fixture.transportAdapter.sentEventsWithSessionTraceState.last)
        if let eventWithSessionArguments = fixture.transportAdapter.sentEventsWithSessionTraceState.last {
            assertValidExceptionEvent(eventWithSessionArguments.event)
            XCTAssertEqual(fixture.session, eventWithSessionArguments.session)
            XCTAssertEqual([TestData.dataAttachment], eventWithSessionArguments.attachments)
        }
    }
    
    func testCaptureExceptionWithSession_WithBeforeSendReturnsNil() throws {
        let sessionBlockExpectation = expectation(description: "session block does not get called")
        sessionBlockExpectation.isInverted = true

        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in return nil }
        }).capture(exception, with: fixture.scope) {
            // This should NOT be called
            sessionBlockExpectation.fulfill()
            return self.fixture.session
        }
        wait(for: [sessionBlockExpectation], timeout: 0.2)
        
        eventId.assertIsEmpty()
    }

    func testCaptureExceptionWithUserInfo() throws {
        let expectedValue = "val"
        let exception = NSException(name: NSExceptionName("exception"), reason: "reason", userInfo: ["key": expectedValue])
        let eventId = fixture.getSut().capture(exception: exception, scope: fixture.scope)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual(expectedValue, actual.context!["user info"]!["key"] as? String)
    }

    func testScopeIsNotNil() throws {
        let eventId = fixture.getSut().capture(message: fixture.messageAsString, scope: fixture.scope)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual(fixture.environment, actual.environment)
    }

    func testCaptureSession() throws {
        let session = SentrySession(releaseName: "release", distinctId: "some-id")
        fixture.getSut().capture(session: session)
        
        XCTAssertNotNil(fixture.transport.sentEnvelopes)
        let actual = try XCTUnwrap(fixture.transport.sentEnvelopes.last)
        XCTAssertEqual(1, actual.items.count)
        XCTAssertEqual("session", try XCTUnwrap(actual.items.first).header.type)
    }
    
    func testCaptureSessionWithoutReleaseName() {
        let session = SentrySession(releaseName: "", distinctId: "some-id")
        
        fixture.getSut().capture(session: session)
        fixture.getSut().capture(exception, with: Scope()) {
            session
        }
            .assertIsNotEmpty()
        fixture.getSut().captureCrash(fixture.event, with: session, with: Scope())
            .assertIsNotEmpty()
        
        // No sessions sent
        XCTAssertTrue(fixture.transport.sentEnvelopes.isEmpty)
        XCTAssertEqual(0, fixture.transportAdapter.sentEventsWithSessionTraceState.count)
        XCTAssertEqual(2, fixture.transportAdapter.sendEventWithTraceStateInvocations.count)
    }

    func testBeforeSendReturnsNil_EventNotSent() {
        beforeSendReturnsNil { $0.capture(message: fixture.messageAsString) }

        assertNoEventSent()
    }
    
    func testBeforeSendReturnsNil_LostEventRecorded() {
        beforeSendReturnsNil { $0.capture(message: fixture.messageAsString) }
        
        assertLostEventRecorded(category: .error, reason: .beforeSend)
    }
    
    func testBeforeSendReturnsNilForTransaction_TransactionNotSend() {
        beforeSendReturnsNil { $0.capture(event: fixture.transaction) }
        
        assertLostEventRecorded(category: .transaction, reason: .beforeSend)
    }
    
    func testBeforeSendReturnsNilForTransaction_LostEventRecorded() {
        beforeSendReturnsNil { $0.capture(event: fixture.transaction) }
        
        assertLostEventRecorded(category: .transaction, reason: .beforeSend)
    }

    func testBeforeSendReturnsNewEvent_NewEventSent() throws {
        let newEvent = Event()
        let releaseName = "1.0.0"
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                newEvent
            }
            options.releaseName = releaseName
        }).capture(message: fixture.messageAsString)

        XCTAssertEqual(newEvent.eventId, eventId)
        let actual = try lastSentEvent()
        XCTAssertEqual(newEvent.eventId, actual.eventId)
        XCTAssertNil(actual.releaseName)
    }
    
    func testBeforeSendModifiesEvent_ModifiedEventSent() throws {
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { event in
                event.threads = []
                event.debugMeta = []
                return event
            }
            options.attachStacktrace = true
        }).capture(message: fixture.messageAsString)

        let actual = try lastSentEvent()
        XCTAssertEqual([], actual.debugMeta)
        XCTAssertEqual([], actual.threads)
    }
    
    func testBeforeSendSpanDitchOneSpan_OtherChangedSpanSent() throws {
        let spanOne = getSpan(operation: "operation.one", tracer: fixture.trace)
        let spanTwo = getSpan(operation: "operation.two", tracer: fixture.trace)
        let transaction = Transaction(trace: fixture.trace, children: [spanOne, spanTwo])
        
        fixture.getSut(configureOptions: { options in
            options.beforeSendSpan = { span in
                if span.operation == "operation.one" {
                    span.operation = "changed"
                    return span
                }
                return nil
            }
        }).capture(event: transaction)
        
        let actual = try lastSentEvent()
        let serialized = actual.serialize()
        let serializedSpans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        XCTAssertEqual(1, serializedSpans.count)
        let serializedSpan = try XCTUnwrap(serializedSpans.first)
        XCTAssertEqual("changed", serializedSpan["op"] as? String)
    }
    
    func testBeforeSendSpanIsNil_SpansUntouched() throws {
        let tracer = fixture.trace
        let span = getSpan(operation: "operation", tracer: tracer)
        let transaction = Transaction(trace: fixture.trace, children: [span])
        fixture.getSut().capture(event: transaction)
        
        let actual = try lastSentEvent()
        let serialized = actual.serialize()
        let serializedSpans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        XCTAssertEqual(1, serializedSpans.count)
        let serializedSpan = try XCTUnwrap(serializedSpans.first)
        XCTAssertEqual("operation", serializedSpan["op"] as? String)
    }
    
    /// Ensure that you can't start and finish new spans in the beforeSendSpan Callback
    func testBeforeSendSpan_StartSpan_ReturnsNoOpSpan() throws {
        let tracer = fixture.trace
        let span = getSpan(operation: "operation", tracer: tracer)
        tracer.finish()
        
        let transaction = Transaction(trace: tracer, children: [span])
        
        fixture.getSut(configureOptions: { options in
            options.beforeSendSpan = { span in
                let childSpan = span.startChild(operation: "op")
                
                XCTAssert(childSpan.isKind(of: SentryNoOpSpan.self))
                
                return span
            }
        }).capture(event: transaction)
        
        let actual = try lastSentEvent()
        let serialized = actual.serialize()
        let serializedSpans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        XCTAssertEqual(1, serializedSpans.count)
    }

    func testNoDsn_MessageNotSent() {
        let sut = fixture.getSutWithNoDsn()
        let eventId = sut.capture(message: fixture.messageAsString)
        eventId.assertIsEmpty()
        assertNothingSent()
    }
    
    func testDisabled_MessageNotSent() {
        let sut = fixture.getSutDisabledSdk()
        let eventId = sut.capture(message: fixture.messageAsString)
        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ExceptionNotSent() {
        let sut = fixture.getSutWithNoDsn()
        let eventId = sut.capture(exception: exception)
        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ErrorNotSent() {
        let sut = fixture.getSutWithNoDsn()
        let eventId = sut.capture(error: error)
        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_SessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).capture(session: fixture.session)

        assertNothingSent()
    }

    func testNoDsn_EventWithSessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).captureCrash(Event(), with: fixture.session, with: fixture.scope)

        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ExceptionWithSessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).capture(self.exception, with: fixture.scope) {
            self.fixture.session
        }

        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ErrorWithSessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).captureError(self.error, with: fixture.scope) {
            self.fixture.session
        }

        eventId.assertIsEmpty()
        assertNothingSent()
    }
    
    func testSampleRateNil_EventNotSampled() throws {
        try assertSampleRate(sampleRate: nil, randomValue: 0, isSampled: false)
    }
    
    func testSampleRateBiggerRandom_EventNotSampled() throws {
        try assertSampleRate(sampleRate: 0.5, randomValue: 0.49, isSampled: false)
    }
    
    func testSampleRateEqualsRandom_EventNotSampled() throws {
        try assertSampleRate(sampleRate: 0.5, randomValue: 0.5, isSampled: false)
    }
    
    func testSampleRateSmallerRandom_EventSampled() throws {
        try assertSampleRate(sampleRate: 0.50, randomValue: 0.51, isSampled: true)
    }
    
    func testSampleRateDoesNotImpactTransactions() throws {
        fixture.random.value = 0.51
        
        let eventId = fixture.getSut(configureOptions: { options in
            options.sampleRate = 0.00
        }).capture(event: fixture.transaction)
        
        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(eventId, actual.eventId)
    }
    
    func testEventSampled_RecordsLostEvent() {
        fixture.getSut(configureOptions: { options in
            options.sampleRate = 0.00
        }).capture(event: TestData.event)
        
        assertLostEventRecorded(category: .error, reason: .sampleRate)
    }
    
    func testEventDroppedByEventProcessor_RecordsLostEvent() {
        SentryGlobalEventProcessor.shared().add { _ in return nil }
        
        beforeSendReturnsNil { $0.capture(message: fixture.messageAsString) }
        
        assertLostEventRecorded(category: .error, reason: .eventProcessor)
    }
    
    func testTransactionDroppedByEventProcessor_RecordsLostEvent() {
        SentryGlobalEventProcessor.shared().add { _ in return nil }
        
        beforeSendReturnsNil { $0.capture(event: fixture.transaction) }
        
        assertLostEventRecorded(category: .transaction, reason: .eventProcessor)
    }
        
    func testRecordEventProcessorDroppingTransaction() {
        SentryGlobalEventProcessor.shared().add { _ in return nil }
        
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        fixture.getSut().capture(event: transaction)
        
        assertLostEventWithCountRecorded(category: .span, reason: .eventProcessor, quantity: 4)
    }
    
    func testRecordEventProcessorDroppingPartiallySpans() {
        SentryGlobalEventProcessor.shared().add { event in
            if let transaction = event as? Transaction {
                transaction.spans = transaction.spans.filter {
                    $0.operation != "child2"
                }
                return transaction
            } else {
                return event
            }
        }
        
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        fixture.getSut().capture(event: transaction)
        
        assertLostEventWithCountRecorded(category: .span, reason: .eventProcessor, quantity: 1)
    }
    
    func testRecordBeforeSendSpanDroppingPartiallySpans() {
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        let numberOfSpansDropped: UInt = 2
        var dropped: UInt = 0
        fixture.getSut(configureOptions: { options in
            options.beforeSendSpan = { span in
                if dropped < numberOfSpansDropped {
                    dropped++
                    return nil
                } else {
                    return span
                }
            }
        }).capture(event: transaction)
        
        assertLostEventWithCountRecorded(category: .span, reason: .beforeSend, quantity: numberOfSpansDropped)
    }
        
    func testRecordBeforeSendDroppingTransaction() {
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                return nil
            }
        }).capture(event: transaction)
        
        assertLostEventWithCountRecorded(category: .span, reason: .beforeSend, quantity: 4)
    }
    
    func testRecordBeforeSendCorrectlyRecordsPartiallyDroppedSpans() {
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { event in
                if let transaction = event as? Transaction {
                    transaction.spans = transaction.spans.filter {
                        $0.operation != "child2"
                    }
                    return transaction
                } else {
                    return event
                }
            }
        }).capture(event: transaction)
        
        // transaction has 3 span children and we dropped 1 of them
        assertLostEventWithCountRecorded(category: .span, reason: .beforeSend, quantity: 1)
    }
    
    func testCombinedPartiallyDroppedSpans() {
        
        SentryGlobalEventProcessor.shared().add { event in
            if let transaction = event as? Transaction {
                transaction.spans = transaction.spans.filter {
                    $0.operation != "child1"
                }
                return transaction
            } else {
                return event
            }
        }
        
        let transaction = Transaction(
            trace: fixture.trace,
            children: [
                fixture.trace.startChild(operation: "child1"),
                fixture.trace.startChild(operation: "child2"),
                fixture.trace.startChild(operation: "child3")
            ]
        )
        
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { event in
                if let transaction = event as? Transaction {
                    transaction.spans = transaction.spans.filter {
                        $0.operation != "child2"
                    }
                    return transaction
                } else {
                    return event
                }
            }
            options.beforeSendSpan = { span in
                if span.operation == "child3" {
                    return nil
                } else {
                    return span
                }
            }
        }).capture(event: transaction)
        
        XCTAssertEqual(3, fixture.transport.recordLostEventsWithCount.count)
        
        // span dropped by event processor
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(0)?.category, SentryDataCategory.span)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(0)?.reason, SentryDiscardReason.eventProcessor)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(0)?.quantity, 1)
        
        // span dropped by beforeSendSpan
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(1)?.category, SentryDataCategory.span)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(1)?.reason, SentryDiscardReason.beforeSend)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(1)?.quantity, 1)
        
        // span dropped by beforeSend
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(2)?.category, SentryDataCategory.span)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(2)?.reason, SentryDiscardReason.beforeSend)
        XCTAssertEqual(fixture.transport.recordLostEventsWithCount.get(2)?.quantity, 1)
    }
    
    func testNoDsn_UserFeedbackNotSent() {
        let sut = fixture.getSutWithNoDsn()
        sut.capture(userFeedback: UserFeedback(eventId: SentryId()))
        assertNothingSent()
    }
    
    func testDisabled_UserFeedbackNotSent() {
        let sut = fixture.getSutDisabledSdk()
        sut.capture(userFeedback: UserFeedback(eventId: SentryId()))
        assertNothingSent()
    }
    
    func testCaptureUserFeedback_WithEmptyEventId() {
        let sut = fixture.getSut()
        sut.capture(userFeedback: UserFeedback(eventId: SentryId.empty))
        assertNothingSent()
    }

    func testDistIsSet() throws {
        let dist = "dist"
        let eventId = fixture.getSut(configureOptions: { options in
            options.dist = dist
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(dist, actual.dist)
    }
    
    func testEnvironmentDefaultToProduction() throws {
        let eventId = fixture.getSut().capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual("production", actual.environment)
    }
    
    func testEnvironmentIsSetViaOptions() throws {
        let environment = "environment"
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = environment
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual(environment, actual.environment)
    }
    
    func testEnvironmentIsSetInEventTakesPrecedenceOverOptions() throws {
        let optionsEnvironment = "environment"
        let event = Event()
        event.environment = "event"
        let scope = fixture.scope
        scope.setEnvironment("scope")
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = optionsEnvironment
        }).capture(event: event, scope: scope)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual("event", actual.environment)
    }
    
    func testEnvironmentIsSetInEventTakesPrecedenceOverScope() throws {
        let optionsEnvironment = "environment"
        let event = Event()
        event.environment = "event"
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = optionsEnvironment
        }).capture(event: event)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        XCTAssertEqual("event", actual.environment)
    }
    
    func testSetSDKIntegrations() throws {
        SentrySDK.start(options: Options())

        let eventId = fixture.getSut().capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        
        var expectedIntegrations = ["AutoBreadcrumbTracking", "AutoSessionTracking", "Crash", "NetworkTracking"]
        if !SentryDependencyContainer.sharedInstance().crashWrapper.isBeingTraced() {
            expectedIntegrations = ["ANRTracking"] + expectedIntegrations
        }
        
        let actual = try lastSentEvent()
        assertArrayEquals(
            expected: expectedIntegrations,
            actual: actual.sdk?["integrations"] as? [String]
        )
    }
    
    func testSetSDKFeatures() throws {
        let sut = fixture.getSut {
            $0.enablePerformanceV2 = true
        }
        
        sut.capture(message: "message")
        
        let actual = try lastSentEvent()
        let features = try XCTUnwrap(actual.sdk?["features"] as? [String])
        XCTAssert(features.contains("performanceV2"))
        XCTAssert(features.contains("captureFailedRequests"))
    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testTrackPreWarmedAppStartTracking() throws {
        try testFeatureTrackingAsIntegration(integrationName: "PreWarmedAppStartTracing") {
            $0.enablePreWarmedAppStartTracing = true
        }
    }
#endif
    
    private func testFeatureTrackingAsIntegration(integrationName: String, configureOptions: (Options) -> Void) throws {
        SentrySDK.start(options: Options())

        let eventId = fixture.getSut(configureOptions: { options in
            configureOptions(options)
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        var expectedIntegrations = ["AutoBreadcrumbTracking", "AutoSessionTracking", "Crash", "NetworkTracking", integrationName]
        if !SentryDependencyContainer.sharedInstance().crashWrapper.isBeingTraced() {
            expectedIntegrations = ["ANRTracking"] + expectedIntegrations
        }
        
        assertArrayEquals(
            expected: expectedIntegrations,
            actual: actual.sdk?["integrations"] as? [String]
        )
    }
    
    func testSetSDKIntegrations_NoIntegrations() throws {
        let expected: [String] = []
        
        let eventId = fixture.getSut(configureOptions: { options in
            options.integrations = expected
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        let actual = try lastSentEvent()
        assertArrayEquals(expected: expected, actual: actual.sdk?["integrations"] as? [String])
    }

    func testFileManagerCantBeInit() {
        SentryFileManager.prepareInitError()

        let options = Options()
        options.dsn = SentryClientTest.dsn
        let client = SentryClient(options: options, dispatchQueue: TestSentryDispatchQueueWrapper(), deleteOldEnvelopeItems: false)

        XCTAssertNil(client)

        SentryFileManager.tearDownInitError()
    }
    
    func testInstallationIdSetWhenNoUserId() throws {
        fixture.getSut().capture(message: "any message")
        
        let actual = try lastSentEvent()
        XCTAssertEqual(SentryInstallation.id(withCacheDirectoryPath: PrivateSentrySDKOnly.options.cacheDirectoryPath), actual.user?.userId)
    }
    
    func testInstallationIdNotSetWhenUserIsSetWithoutId() throws {
        let scope = fixture.scope
        scope.setUser(fixture.user)
        fixture.getSut().capture(message: "any message", scope: scope)
        
        let actual = try lastSentEventWithAttachment()
        XCTAssertEqual(fixture.user.userId, actual.user?.userId)
        XCTAssertEqual(fixture.user.email, actual.user?.email)
    }
    
    func testInstallationIdNotSetWhenUserIsSetWithId() throws {
        let scope = Scope()
        let user = fixture.user
        user.userId = "id"
        scope.setUser(user)
        fixture.getSut().capture(message: "any message", scope: scope)
        
        let actual = try lastSentEvent()
        XCTAssertEqual(user.userId, actual.user?.userId)
        XCTAssertEqual(fixture.user.email, actual.user?.email)
    }
    
    func testSendDefaultPiiEnabled_GivenNoIP_AutoIsSet() throws {
        fixture.getSut(configureOptions: { options in
            options.sendDefaultPii = true
        }).capture(message: "any")
        
        let actual = try lastSentEvent()
        XCTAssertEqual("{{auto}}", actual.user?.ipAddress)
    }
    
    func testSendDefaultPiiEnabled_GivenIP_IPAddressNotChanged() throws {
        let scope = Scope()
        scope.setUser(fixture.user)
        
        fixture.getSut(configureOptions: { options in
            options.sendDefaultPii = true
        }).capture(message: "any", scope: scope)
        
        let actual = try lastSentEvent()
        XCTAssertEqual(fixture.user.ipAddress, actual.user?.ipAddress)
    }
    
    func testSendDefaultPiiDisabled_GivenIP_IPAddressNotChanged() throws {
        let scope = Scope()
        scope.setUser(fixture.user)
        
        fixture.getSut().capture(message: "any", scope: scope)
        
        let actual = try lastSentEvent()
        XCTAssertEqual(fixture.user.ipAddress, actual.user?.ipAddress)
    }
    
    func testStoreEnvelope_StoresEnvelopeToDisk() {
        fixture.getSut().store(SentryEnvelope(event: Event()))
        XCTAssertEqual(1, fixture.fileManager.getAllEnvelopes().count)
    }
    
    func testOnCrashedLastRun_OnCaptureCrashWithSession() {
        let event = TestData.event
        
        var onCrashedLastRunCalled = false
        fixture.getSut(configureOptions: { options in
            options.onCrashedLastRun = { _ in
                onCrashedLastRunCalled = true
            }
        }).captureCrash(event, with: fixture.session, with: fixture.scope)
        
        XCTAssertTrue(onCrashedLastRunCalled)
    }
    
    func testOnCrashedLastRun_DontRunIfBeforeSendReturnsNill() {
        let event = TestData.event
        
        var onCrashedLastRunCalled = false
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                return nil
            }
            options.onCrashedLastRun = { _ in
                onCrashedLastRunCalled = true
            }
        }).captureCrash(event, with: fixture.session, with: fixture.scope)
        
        XCTAssertFalse(onCrashedLastRunCalled)
    }
    
    func testOnCrashedLastRun_WithTwoCrashes_OnlyInvokeCallbackOnce() {
        let event = TestData.event
        
        var onCrashedLastRunCalled = false
        let client = fixture.getSut(configureOptions: { options in
            options.onCrashedLastRun = { crashEvent in
                onCrashedLastRunCalled = true
                XCTAssertEqual(event.eventId, crashEvent.eventId)
            }
        })
        
        client.captureCrash(event, with: fixture.scope)
        client.captureCrash(TestData.event, with: fixture.scope)
        
        XCTAssertTrue(onCrashedLastRunCalled)
    }
    
    func testOnCrashedLastRun_WithoutCallback_DoesNothing() {
        let client = fixture.getSut()
        client.captureCrash(TestData.event, with: fixture.scope)
    }
    
    func testOnCrashedLastRun_CallingCaptureCrash_OnlyInvokeCallbackOnce() {
        let event = TestData.event
        let callbackExpectation = expectation(description: "onCrashedLastRun called")
        
        var captureCrash: (() -> Void)?
        
        let client = fixture.getSut(configureOptions: { options in
            options.onCrashedLastRun = { crashEvent in
                callbackExpectation.fulfill()
                XCTAssertEqual(event.eventId, crashEvent.eventId)
                captureCrash!()
            }
        })
        captureCrash = { client.captureCrash(event, with: self.fixture.scope) }
        
        client.captureCrash(event, with: fixture.scope)
        
        wait(for: [callbackExpectation], timeout: 0.1)
    }
    
    func testCaptureTransactionEvent_sendTraceState() {
        let transaction = fixture.transaction
        let client = fixture.getSut()
        client.capture(event: transaction)

        XCTAssertNotNil(fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.traceContext)
        XCTAssertEqual(fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.traceContext?.traceId, transaction.trace.traceId)
    }
    
    func testCaptureEvent_sendTraceState() {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        let scope = Scope()
        scope.span = fixture.trace
        
        let client = fixture.getSut()
        client.capture(event: event, scope: scope)

        XCTAssertNotNil(fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.traceContext)
        XCTAssertEqual(fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.traceContext?.traceId, fixture.trace.traceId)
    }

    func test_AddCrashReportAttacment_withViewHierarchy() throws {
        let scope = Scope()

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("view-hierarchy.json")
        try "data".data(using: .utf8)?.write(to: tempFile)

        scope.addCrashReportAttachment(inPath: tempFile.path)

        XCTAssertEqual(scope.attachments.count, 1)
        XCTAssertEqual(scope.attachments.first?.filename, "view-hierarchy.json")
        XCTAssertEqual(scope.attachments.first?.contentType, "application/json")
        XCTAssertEqual(scope.attachments.first?.attachmentType, .viewHierarchy)
    }
    
    func testCaptureEvent_withAdditionalEnvelopeItem() {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        
        let attachment = "{}"
        let data = attachment.data(using: .utf8)!
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(data.count))
        let item = SentryEnvelopeItem(header: itemHeader, data: data)
        
        let client = fixture.getSut()
        client.capture(event: event, scope: Scope(), additionalEnvelopeItems: [item])
        
        XCTAssertEqual(item, fixture.transportAdapter.sendEventWithTraceStateInvocations.first?.additionalEnvelopeItems.first)
    }
    
    func testConcurrentlyAddingInstalledIntegrations_WhileSendingEvents() {
        let sut = fixture.getSut()
        
        let hub = SentryHub(client: sut, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        func addIntegrations(amount: Int) {
            let emptyIntegration = EmptyIntegration()
            for i in 0..<amount {
                hub.addInstalledIntegration(emptyIntegration, name: "Integration\(i)")
            }
        }
        
        // So that the loop in Client.setSDK overlaps with addingIntegrations
        addIntegrations(amount: 1_000)
        
        let queue = fixture.queue
        let group = DispatchGroup()
        
        // Run this in a loop to ensure that add while iterating over the integrations
        // Running it once doesn't guaranty failure
        for _ in 0..<10 {
            group.enter()
            queue.async {
                addIntegrations(amount: 1_000)
                group.leave()
            }
            
            sut.capture(event: Event())
            group.waitWithTimeout()
            hub.removeAllIntegrations()
        }
    }
    
    func testCaptureReplayEvent() {
        let sut = fixture.getSut()
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 2)
        let replayRecording = SentryReplayRecording(segmentId: 2, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        
        //Not a video url, but its ok for test the envelope
        let movieUrl = Bundle(for: self.classForCoder).url(forResource: "Resources/raw", withExtension: "json")
        
        sut.capture(replayEvent, replayRecording: replayRecording, video: movieUrl!, with: Scope())
        let envelope = fixture.transport.sentEnvelopes.first
        XCTAssertEqual(try XCTUnwrap(envelope?.items.first).header.type, SentryEnvelopeItemTypeReplayVideo)
    }
    
    func testCaptureReplayEvent_WrongEventFromEventProcessor() {
        let sut = fixture.getSut()
        sut.options.beforeSend = { _ in
            return Event()
        }
        
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 2)
        let replayRecording = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        
        let movieUrl = Bundle(for: self.classForCoder).url(forResource: "Resources/raw", withExtension: "json")
        sut.capture(replayEvent, replayRecording: replayRecording, video: movieUrl!, with: Scope())
        
        //Nothing should be captured because beforeSend returned a non ReplayEvent
        XCTAssertEqual(self.fixture.transport.sentEnvelopes.count, 0)
    }
    
    func testCaptureReplayEvent_DontCaptureNilEvent() {
        let sut = fixture.getSut()
        sut.options.beforeSend = { _ in
            return nil
        }
        
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 2)
        let replayRecording = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        
        let movieUrl = Bundle(for: self.classForCoder).url(forResource: "Resources/raw", withExtension: "json")
        sut.capture(replayEvent, replayRecording: replayRecording, video: movieUrl!, with: Scope())
        
        //Nothing should be captured because beforeSend returned nil
        XCTAssertEqual(self.fixture.transport.sentEnvelopes.count, 0)
    }
    
    func testCaptureReplayEvent_InvalidFile() {
        let sut = fixture.getSut()
        sut.options.beforeSend = { _ in
            return nil
        }
        
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 2)
        let replayRecording = SentryReplayRecording(segmentId: 3, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        
        let movieUrl = URL(string: "NoFile")!
        sut.capture(replayEvent, replayRecording: replayRecording, video: movieUrl, with: Scope())
        
        //Nothing should be captured because beforeSend returned nil
        XCTAssertEqual(self.fixture.transport.sentEnvelopes.count, 0)
    }
    
    func testCaptureReplayEvent_noBradcrumbsThreadsDebugMeta() {
        let sut = fixture.getSut()
        let replayEvent = SentryReplayEvent(eventId: SentryId(), replayStartTimestamp: Date(), replayType: .session, segmentId: 2)
        let replayRecording = SentryReplayRecording(segmentId: 2, size: 200, start: Date(timeIntervalSince1970: 2), duration: 5_000, frameCount: 5, frameRate: 1, height: 930, width: 390, extraEvents: [])
        
        //Not a video url, but its ok for test the envelope
        let movieUrl = Bundle(for: self.classForCoder).url(forResource: "Resources/raw", withExtension: "json")
        
        let scope = Scope()
        scope.addBreadcrumb(Breadcrumb(level: .debug, category: "Test Breadcrumb"))
        
        sut.capture(replayEvent, replayRecording: replayRecording, video: movieUrl!, with: scope)
        
        XCTAssertNil(replayEvent.breadcrumbs)
        XCTAssertNil(replayEvent.threads)
        XCTAssertNil(replayEvent.debugMeta)
    }
    
    func testCaptureCrashEventSetReplayInScope() {
        let sut = fixture.getSut()
        let event = Event()
        event.isCrashEvent = true
        let scope = Scope()
        event.context = ["replay": ["replay_id": "someReplay"]]
        sut.captureCrash(event, with: SentrySession(releaseName: "", distinctId: ""), with: scope)
        XCTAssertEqual(scope.replayId, "someReplay")
    }
}

private extension SentryClientTest {
    private func givenEventWithDebugMeta() -> Event {
        let event = Event(level: SentryLevel.fatal)
        let debugMeta = DebugMeta()
        debugMeta.name = "Me"
        let debugMetas = [debugMeta]
        event.debugMeta = debugMetas
        return event
    }
    
    private func givenEventWithThreads() -> Event {
        let event = Event(level: SentryLevel.fatal)
        let thread = SentryThread(threadId: 1)
        thread.crashed = true
        let threads = [thread]
        event.threads = threads
        return event
    }
    
    private func getSpan(operation: String, tracer: SentryTracer) -> Span {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        return SentrySpan(tracer: tracer, context: SpanContext(operation: operation), framesTracker: nil)
#else
        return  SentrySpan(tracer: tracer, context: SpanContext(operation: operation))
        #endif
    }
    
    private func beforeSendReturnsNil(capture: (SentryClient) -> Void) {
        capture(fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                nil
            }
        }))
    }
    
    private func assertNoEventSent() {
        XCTAssertEqual(0, fixture.transportAdapter.sendEventWithTraceStateInvocations.count, "No events should have been sent.")
    }
    
    private func assertEventNotSent(eventId: SentryId?) {
        let eventWasSent = fixture.transportAdapter.sendEventWithTraceStateInvocations.invocations.contains { eventArguments in
            eventArguments.event.eventId == eventId
        }
        XCTAssertFalse(eventWasSent)
    }

    private func lastSentEvent() throws -> Event {
        XCTAssertNotNil(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        let lastSentEventArguments = try XCTUnwrap(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        return lastSentEventArguments.event
    }
    
    private func lastSentEventWithAttachment() throws -> Event {
        XCTAssertNotNil(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        let lastSentEventArguments = try XCTUnwrap(fixture.transportAdapter.sendEventWithTraceStateInvocations.last)
        XCTAssertEqual([TestData.dataAttachment], lastSentEventArguments.attachments)
        return lastSentEventArguments.event
    }
    
    private func assertValidErrorEvent(_ event: Event, _ expectedError: NSError, exceptionValue: String? = nil) throws {
        XCTAssertEqual(SentryLevel.error, event.level)
        XCTAssertEqual(expectedError, event.error as NSError?)
        
        guard let exceptions = event.exceptions else {
            XCTFail("Event should contain one exception"); return
        }
        XCTAssertEqual(1, exceptions.count)
        let exception = try XCTUnwrap(exceptions.first)
        XCTAssertEqual(expectedError.domain, exception.type)
        
        XCTAssertEqual(exceptionValue ?? "Code: \(expectedError.code)", exception.value)
        
        XCTAssertNil(exception.threadId)
        XCTAssertNil(exception.stacktrace)

        let mechanism = try XCTUnwrap(exception.mechanism)
        let meta = try XCTUnwrap(mechanism.meta)
        let actualError = try XCTUnwrap(meta.error)
        XCTAssertEqual("NSError", mechanism.type)
        XCTAssertEqual(expectedError.domain, Dynamic(actualError).domain.asString)
        XCTAssertEqual(expectedError.code, Dynamic(actualError).code.asInt)
        
        assertValidDebugMeta(actual: event.debugMeta, forThreads: event.threads)
        assertValidThreads(actual: event.threads)
    }
    
    private func assertValidExceptionEvent(_ event: Event) {
        XCTAssertEqual(SentryLevel.error, event.level)
        XCTAssertEqual(exception.reason, event.exceptions!.first!.value)
        XCTAssertEqual(exception.name.rawValue, event.exceptions!.first!.type)
        assertValidDebugMeta(actual: event.debugMeta, forThreads: event.threads)
        assertValidThreads(actual: event.threads)
    }
    
    private func assertValidDebugMeta(actual: [DebugMeta]?, forThreads threads: [SentryThread]?) {
        let debugMetas = fixture.debugImageBuilder.getDebugImages(for: threads ?? [], isCrash: false)
        
        XCTAssertEqual(debugMetas, actual ?? [])
    }
    
    private func assertValidThreads(actual: [SentryThread]?) {
        let expected = fixture.threadInspector.getCurrentThreads()
        XCTAssertEqual(expected.count, actual?.count)
        XCTAssertEqual(expected, actual)
    }
    
    private func shortenIntegrations(_ integrations: [String]?) -> [String]? {
        return integrations?.map { $0.replacingOccurrences(of: "Sentry", with: "").replacingOccurrences(of: "Integration", with: "") }
    }

    private func assertNothingSent() {
        XCTAssertTrue(fixture.transport.sentEnvelopes.isEmpty)
        XCTAssertEqual(0, fixture.transportAdapter.sentEventsWithSessionTraceState.count)
        XCTAssertEqual(0, fixture.transportAdapter.sendEventWithTraceStateInvocations.count)
        XCTAssertEqual(0, fixture.transportAdapter.userFeedbackInvocations.count)
    }
    
    private func assertLostEventRecorded(category: SentryDataCategory, reason: SentryDiscardReason) {
        XCTAssertEqual(1, fixture.transport.recordLostEvents.count)
        let lostEvent = fixture.transport.recordLostEvents.first
        XCTAssertEqual(category, lostEvent?.category)
        XCTAssertEqual(reason, lostEvent?.reason)
    }

    private func assertLostEventWithCountRecorded(category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        XCTAssertEqual(1, fixture.transport.recordLostEventsWithCount.count)
        let lostEvent = fixture.transport.recordLostEventsWithCount.first
        XCTAssertEqual(category, lostEvent?.category)
        XCTAssertEqual(reason, lostEvent?.reason)
        XCTAssertEqual(quantity, lostEvent?.quantity)
    }
    
    private enum TestError: Error {
        case invalidTest
        case testIsFailing
        case somethingElse
    }
    
    class TestAttachmentProcessor: NSObject, SentryClientAttachmentProcessor {
        
        var callback: (([Attachment]?, Event) -> [Attachment]?)
        
        init(callback: @escaping ([Attachment]?, Event) -> [Attachment]?) {
            self.callback = callback
        }
        
        func processAttachments(_ attachments: [Attachment]?, for event: Event) -> [Attachment]? {
            return callback(attachments, event)
        }
    }
    
#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
    class TestSentryUIApplication: SentryUIApplication {
        override func relevantViewControllers() -> [UIViewController] {
            return [ClientTestViewController()]
        }
        
        private var _underlyingAppState: UIApplication.State = .active
        override var applicationState: UIApplication.State {
            get { _underlyingAppState }
            set { _underlyingAppState = newValue }
        }
    }
    
    class ClientTestViewController: UIViewController {
        
    }
#endif
    
    func assertSampleRate( sampleRate: NSNumber?, randomValue: Double, isSampled: Bool) throws {
        fixture.random.value = randomValue
        
        let eventId = fixture.getSut(configureOptions: { options in
            options.sampleRate = sampleRate
        }).capture(event: TestData.event)
        
        if isSampled {
            eventId.assertIsEmpty()
            assertNothingSent()
        } else {
            eventId.assertIsNotEmpty()
            let actual = try lastSentEvent()
            XCTAssertEqual(eventId, actual.eventId)
        }
    }
    
}

enum SentryClientError: Error {
    case someError
    case invalidInput(String)
}

enum SentryClientErrorWithDebugDescription: Error {
    case someError
}

extension SentryClientErrorWithDebugDescription: CustomNSError {
    var errorUserInfo: [String: Any] {
        func getDebugDescription() -> String {
            switch self {
            case .someError:
                return  "anotherError"
            }
        }

        return [NSDebugDescriptionErrorKey: getDebugDescription()]
    }
}

// swiftlint:enable file_length
