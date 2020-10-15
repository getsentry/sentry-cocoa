@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryClientTest: XCTestCase {

    private class Fixture {
        let transport = TestTransport()
        
        let debugMetaBuilder = SentryDebugMetaBuilder(
            binaryImageProvider: SentryCrashDefaultBinaryImageProvider()
        )
        
        let threadInspector = SentryThreadInspector(
            stacktraceBuilder: SentryStacktraceBuilder(sentryFrameRemover: SentryFrameRemover()),
            andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper()
        )
        
        let session: SentrySession
        let event: Event
        let environment = "Environment"
        let messageAsString = "message"
        let message: SentryMessage
        
        let user: User

        init() {
            session = SentrySession(releaseName: "release")
            session.incrementErrors()

            message = SentryMessage(formatted: messageAsString)

            event = Event()
            event.message = message
            
            user = User()
            user.email = "someone@sentry.io"
        }

        func getSut(configureOptions: (Options) -> Void = { _ in }) -> Client {
            var client: Client!
            do {
                let options = try Options(dict: [
                    "dsn": TestConstants.dsnAsString
                ])
                configureOptions(options)

                client = Client(options: options, andTransport: transport, andFileManager: try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider()))
            } catch {
                XCTFail("Options could not be created")
            }

            return client
        }

        func getSutWithNoDsn() -> Client {
            getSut(configureOptions: { options in
                options.parsedDsn = nil
            })
        }

        var scope: Scope {
            get {
                let scope = Scope()
                scope.setEnvironment(environment)
                scope.setTag(value: "value", key: "key")
                return scope
            }
        }
    }

    private let error = NSError(domain: "domain", code: -20, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])

    private let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testCaptureMessage() {
        let eventId = fixture.getSut().capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.info, actual.level)
            XCTAssertEqual(fixture.message, actual.message)

            assertValidDebugMeta(actual: actual.debugMeta)
            assertValidThreads(actual: actual.threads)
        }
    }

    func testCaptureMessageWithOutStacktrace() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(message: fixture.messageAsString)

        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.info, actual.level)
            XCTAssertEqual(fixture.message, actual.message)
            XCTAssertNil(actual.debugMeta)
            XCTAssertNil(actual.threads)
            XCTAssertNotNil(actual.dist)
        }
    }
    
    func testCaptureEvent() {
        let event = Event(level: SentryLevel.warning)
        event.message = fixture.message
        let scope = Scope()
        let expectedTags = ["tagKey": "tagValue"]
        scope.setTags(expectedTags)
        
        let eventId = fixture.getSut().capture(event: event, scope: scope)
        
        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(event.level, actual.level)
            XCTAssertEqual(event.message, actual.message)
            XCTAssertNotNil(actual.debugMeta)
            XCTAssertNotNil(actual.threads)
            
            XCTAssertNotNil(actual.tags)
            if let actualTags = actual.tags {
                XCTAssertEqual(expectedTags, actualTags)
            }
        }
    }
    
    func testCaptureEventWithException() {
        let event = Event()
        event.exceptions = [ Exception(value: "", type: "")]
        
        fixture.getSut().capture(event: event, scope: fixture.scope)
        
        assertLastSentEvent { actual in
            assertValidDebugMeta(actual: actual.debugMeta)
            assertValidThreads(actual: actual.threads)
        }
    }

    func testCaptureEventWithNoDsn() {
        let event = Event()

        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).capture(event: event)
        
        eventId.assertIsEmpty()
    }

    func testCaptureEventWithDsnSetAfterwards() {
        let event = Event()

        let sut = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        })
        
        sut.options.dsn = TestConstants.dsnAsString
        
        let eventId = sut.capture(event: event)
        eventId.assertIsNotEmpty()
    }
    
    func testCaptureEventWithDebugMeta_KeepsDebugMeta() {
        let sut = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        })
        
        let event = givenEventWithDebugMeta()
        sut.capture(event: event)
        
        assertLastSentEvent { actual in
            XCTAssertEqual(event.debugMeta, actual.debugMeta)
            assertValidThreads(actual: actual.threads)
        }
    }
    
    func testCaptureEventWithAttachedThreads_KeepsThreads() {
        let sut = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        })
        
        let event = givenEventWithThreads()
        sut.capture(event: event)
        
        assertLastSentEvent { actual in
            assertValidDebugMeta(actual: actual.debugMeta)
            XCTAssertEqual(event.threads, actual.threads)
        }
    }
    
    func testCaptureEventWithAttachStacktrace() {
        let event = Event(level: SentryLevel.fatal)
        event.message = fixture.message
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        }).capture(event: event)
        
        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            XCTAssertEqual(event.level, actual.level)
            XCTAssertEqual(event.message, actual.message)
            assertValidDebugMeta(actual: actual.debugMeta)
            assertValidThreads(actual: actual.threads)
        }
    }
    
    func testCaptureErrorWithoutAttachStacktrace() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(error: error, scope: fixture.scope)
        
        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            assertValidErrorEvent(actual)
        }
    }
    
    func testCaptureErrorWithEnum() {
        let eventId = fixture.getSut().capture(error: TestError.invalidTest)

        eventId.assertIsNotEmpty()
        let error = TestError.invalidTest as NSError
        assertLastSentEvent { actual in
            XCTAssertEqual("\(error.domain) \(error.code)", actual.message.formatted)
            XCTAssertEqual("\(error.domain) %s", actual.message.message)
            XCTAssertEqual(["\(error.code)"], actual.message.params)
        }
    }

    func testCaptureErrorWithComplexUserInfo() {
        let url = URL(string: "https://github.com/getsentry")!
        let error = NSError(domain: "domain", code: 0, userInfo: ["url": url])
        let eventId = fixture.getSut().capture(error: error, scope: fixture.scope)

        eventId.assertIsNotEmpty()

        assertLastSentEvent { actual in
            XCTAssertEqual(url.absoluteString, actual.context!["user info"]!["url"] as? String)
        }
    }

    func testCaptureErrorWithSession() {
        let eventId = fixture.getSut().captureError(error, with: fixture.session, with: Scope())
        
        eventId.assertIsNotEmpty()
        XCTAssertNotNil(fixture.transport.sentEventsWithSession.last)
        if let eventWithSessionArguments = fixture.transport.sentEventsWithSession.last {
            assertValidErrorEvent(eventWithSessionArguments.first)
            XCTAssertEqual(fixture.session, eventWithSessionArguments.second)
        }
    }
    
    func testCaptureErrorWithSession_WithBeforeSendReturnsNil() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in return nil }
        }).captureError(error, with: fixture.session, with: Scope())
        
        eventId.assertIsEmpty()
        assertLastSentEnvelopeIsASession()
    }

    func testCaptureEventWithSession() {
        let eventId = fixture.getSut().capture(fixture.event, with: fixture.session, with: fixture.scope)

        eventId.assertIsNotEmpty()
        XCTAssertNotNil(fixture.transport.sentEventsWithSession.last)
        if let eventWithSessionArguments = fixture.transport.sentEventsWithSession.last {
            let event = eventWithSessionArguments.first
            XCTAssertEqual(fixture.event.eventId, event.eventId)
            XCTAssertEqual(fixture.event.message, event.message)
            XCTAssertEqual("value", event.tags?["key"] ?? "")

            XCTAssertEqual(fixture.session, eventWithSessionArguments.second)
        }

    }

    func testCaptureErrorWithUserInfo() {
        let expectedValue = "val"
        let error = NSError(domain: "domain", code: 0, userInfo: ["key": expectedValue])
        let eventId = fixture.getSut().capture(error: error, scope: fixture.scope)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(expectedValue, actual.context!["user info"]!["key"] as? String)
        }
    }

    func testCaptureExceptionWithoutAttachStacktrace() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = false
        }).capture(exception: exception, scope: fixture.scope)
        
        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            assertValidExceptionEvent(actual)
        }
    }
    
    func testCaptureExceptionWithSession() {
        let eventId = fixture.getSut().capture(exception, with: fixture.session, with: Scope())
        
        eventId.assertIsNotEmpty()
        XCTAssertNotNil(fixture.transport.sentEventsWithSession.last)
        if let eventWithSessionArguments = fixture.transport.sentEventsWithSession.last {
            assertValidExceptionEvent(eventWithSessionArguments.first)
            XCTAssertEqual(fixture.session, eventWithSessionArguments.second)
        }
    }
    
    func testCaptureExceptionWithSession_WithBeforeSendReturnsNil() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in return nil }
        }).capture(exception, with: fixture.session, with: Scope())
        
        eventId.assertIsEmpty()
        assertLastSentEnvelopeIsASession()
    }

    func testCaptureExceptionWithUserInfo() {
        let expectedValue = "val"
        let exception = NSException(name: NSExceptionName("exception"), reason: "reason", userInfo: ["key": expectedValue])
        let eventId = fixture.getSut().capture(exception: exception, scope: fixture.scope)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(expectedValue, actual.context!["user info"]!["key"] as? String)
        }
    }

    func testScopeIsNotNil() {
        let eventId = fixture.getSut().capture(message: fixture.messageAsString, scope: fixture.scope)

        eventId.assertIsNotEmpty()
        assertLastSentEvent { actual in
            XCTAssertEqual(fixture.environment, actual.environment)
        }
    }

    func testCaptureSession() {
        let session = SentrySession(releaseName: "release")
        fixture.getSut().capture(session: session)

        assertLastSentEnvelopeIsASession()
    }

    func testBeforeSendReturnsNil_EventNotSent() {
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                nil
            }
        }).capture(message: fixture.messageAsString)

        assertNoEventSent()
    }

    func testBeforeSendReturnsNewEvent_NewEventSent() {
        let newEvent = Event()
        let releaseName = "1.0.0"
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                newEvent
            }
            options.releaseName = releaseName
        }).capture(message: fixture.messageAsString)

        XCTAssertEqual(newEvent.eventId, eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(newEvent.eventId, actual.eventId)
            XCTAssertNil(actual.releaseName)
        }
    }
    
    func testBeforeSendModifiesEvent_ModifiedEventSent() {
        fixture.getSut(configureOptions: { options in
            options.beforeSend = { event in
                event.threads = []
                event.debugMeta = []
                return event
            }
            options.attachStacktrace = true
        }).capture(message: fixture.messageAsString)

        assertLastSentEvent { actual in
            XCTAssertEqual([], actual.debugMeta)
            XCTAssertEqual([], actual.threads)
        }
    }

    func testNoDsn_MessageNotSent() {
        let sut = fixture.getSutWithNoDsn()
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
        }).capture(Event(), with: fixture.session, with: Scope())

        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ExceptionWithSessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).capture(self.exception, with: fixture.session, with: Scope())

        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testNoDsn_ErrorWithSessionsNotSent() {
        _ = SentryEnvelope(event: Event())
        let eventId = fixture.getSut(configureOptions: { options in
            options.dsn = nil
        }).captureError(self.error, with: fixture.session, with: Scope())

        eventId.assertIsEmpty()
        assertNothingSent()
    }

    func testDistIsSet() {
        let dist = "dist"
        let eventId = fixture.getSut(configureOptions: { options in
            options.dist = dist
        }).capture(message: fixture.messageAsString)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(dist, actual.dist)
        }
    }

    func testEnvironmentIsSet() {
        let environment = "environment"
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = environment
        }).capture(message: fixture.messageAsString)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(environment, actual.environment)
        }
    }
    
    func testFileManagerCantBeInit() {
        SentryFileManager.prepareInitError()
        
        let options = Options()
        options.dsn = TestConstants.dsnAsString
        let client = Client(options: options)
        
        XCTAssertNil(client)
        
        SentryFileManager.tearDownInitError()
    }
    
    func testInstallationIdSetWhenNoUserId() {
        fixture.getSut().capture(message: "any message")
        
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryInstallation.id(), actual.user?.userId)
        }
    }
    
    func testInstallationIdNotSetWhenUserIsSetWithoutId() {
        let scope = Scope()
        scope.setUser(fixture.user)
        fixture.getSut().capture(message: "any message", scope: scope)
        
        assertLastSentEvent { actual in
            XCTAssertEqual(fixture.user.userId, actual.user?.userId)
            XCTAssertEqual(fixture.user.email, actual.user?.email)
        }
    }
    
    func testInstallationIdNotSetWhenUserIsSetWithId() {
        let scope = Scope()
        let user = fixture.user
        user.userId = "id"
        scope.setUser(user)
        fixture.getSut().capture(message: "any message", scope: scope)
        
        assertLastSentEvent { actual in
            XCTAssertEqual(user.userId, actual.user?.userId)
            XCTAssertEqual(fixture.user.email, actual.user?.email)
        }
    }
    
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
        let thread = Sentry.Thread(threadId: 1)
        thread.crashed = true
        let threads = [thread]
        event.threads = threads
        return event
    }
    
    private func assertNoEventSent() {
        XCTAssertEqual(0, fixture.transport.sentEvents.count, "No events should have been sent.")
    }
    
    private func assertEventNotSent(eventId: SentryId?) {
        let eventWasSent = fixture.transport.sentEvents.contains { event in
            event.eventId == eventId
        }
        XCTAssertFalse(eventWasSent)
    }

    private func assertLastSentEvent(assert: (Event) -> Void) {
        XCTAssertNotNil(fixture.transport.sentEvents.last)
        if let lastSentEvent = fixture.transport.sentEvents.last {
            assert(lastSentEvent)
        }
    }
    
    private func assertValidErrorEvent(_ event: Event) {
        XCTAssertEqual(SentryLevel.error, event.level)
        XCTAssertEqual("\(error.domain) \(error.code)", event.message.formatted)
        XCTAssertEqual("\(error.domain) %s", event.message.message)
        XCTAssertEqual(["\(error.code)"], event.message.params)
        assertValidDebugMeta(actual: event.debugMeta)
        assertValidThreads(actual: event.threads)
    }
    
    private func assertValidExceptionEvent(_ event: Event) {
        XCTAssertEqual(SentryLevel.error, event.level)
        XCTAssertEqual(exception.reason, event.exceptions!.first!.value)
        XCTAssertEqual(exception.name.rawValue, event.exceptions!.first!.type)
        assertValidDebugMeta(actual: event.debugMeta)
        assertValidThreads(actual: event.threads)
    }
    
    private func assertLastSentEnvelope(assert: (SentryEnvelope) -> Void) {
        XCTAssertNotNil(fixture.transport.lastSentEnvelope)
        if let lastSentEnvelope = fixture.transport.lastSentEnvelope {
            assert(lastSentEnvelope)
        }
    }
    
    private func assertLastSentEnvelopeIsASession() {
        assertLastSentEnvelope { actual in
            XCTAssertEqual(1, actual.items.count)
            XCTAssertEqual("session", actual.items[0].header.type)
        }
    }
    
    private func assertValidDebugMeta(actual: [DebugMeta]?) {
        let debugMetas = fixture.debugMetaBuilder.buildDebugMeta()
        
        XCTAssertEqual(debugMetas, actual ?? [])
    }
    
    private func assertValidThreads(actual: [Sentry.Thread]?) {
        let expected = fixture.threadInspector.getCurrentThreads()

        // We can only compare the stacktrace up to the test method. Therefore we
        // need to remove a few frames for the stacktraces.
        removeFrames(threads: expected)
        removeFrames(threads: actual ?? [])
        
        XCTAssertEqual(expected.count, actual?.count)
        XCTAssertEqual(expected, actual ?? [])
    }

    private func removeFrames(threads: [Sentry.Thread]) {
        var actualFrames = threads[0].stacktrace?.frames ?? []
        XCTAssertTrue(actualFrames.count > 1, "Event has no stacktrace.")
        if actualFrames.count > 1 {
            actualFrames.removeLast(3)
            threads[0].stacktrace?.frames = actualFrames
        }
    }

    private func assertNothingSent() {
        XCTAssertNil(fixture.transport.lastSentEnvelope)
        XCTAssertEqual(0, fixture.transport.sentEventsWithSession.count)
        XCTAssertEqual(0, fixture.transport.sentEvents.count)
    }

    private enum TestError: Error {
        case invalidTest
        case testIsFailing
        case somethingElse
    }
}
