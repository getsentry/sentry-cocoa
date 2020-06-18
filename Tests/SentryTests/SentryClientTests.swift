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
            stacktraceBuilder: SentryStacktraceBuilder(),
            andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper()
        )

        func getSut(configureOptions: (Options) -> Void = { _ in }) -> Client {
            var client: Client!
            do {
                let options = try Options(dict: [
                    "dsn": TestConstants.dsnAsString
                ])
                configureOptions(options)

                client = Client(options: options, andTransport: transport, andFileManager: try SentryFileManager(dsn: TestConstants.dsn))
            } catch {
                XCTFail("Options could not be created")
            }

            return client
        }

        func getSutWithDisabledSdk() -> Client {
            getSut(configureOptions: { options in
                options.enabled = false
            })
        }
    }

    private let error = NSError(domain: "domain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
    
    private let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)
    
    private let environment = "Environment"
    private var scope: Scope {
        get {
            let scope = Scope()
            scope.setEnvironment(environment)
            return scope
        }
    }
    
    private let message = "message"
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testCaptureMessage() {
        let eventId = fixture.getSut().capture(message: message, scope: nil)

        XCTAssertNotNil(eventId)

        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.info, actual.level)
            XCTAssertEqual(message, actual.message)
            XCTAssertNil(actual.debugMeta)
            XCTAssertNil(actual.threads)
            XCTAssertNotNil(actual.dist)
        }
    }

    func testCaptureMessageWithStacktrace() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        }).capture(message: message, scope: nil)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.info, actual.level)
            XCTAssertEqual(message, actual.message)
            
            assertValidStacktrace(actual: actual)
        }
    }
    
    func testCaptureEvent() {
        let event = Event(level: SentryLevel.warning)
        event.message = message
        let scope = Scope()
        let expectedTags = ["tagKey": "tagValue"]
        scope.setTags(expectedTags)
        
        let eventId = fixture.getSut().capture(event: event, scope: scope)
        
        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(event.level, actual.level)
            XCTAssertEqual(event.message, actual.message)
            XCTAssertNil(actual.debugMeta)
            XCTAssertNil(actual.threads)
            
            XCTAssertNotNil(actual.tags)
            if let actualTags = actual.tags {
                XCTAssertEqual(expectedTags, actualTags)
            }
        }
    }
    
    func testCaptureEventWithStacktrace() {
        let event = Event(level: SentryLevel.fatal)
        event.message = message
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        }).capture(event: event, scope: nil)
        
        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(event.level, actual.level)
            XCTAssertEqual(event.message, actual.message)
            assertValidStacktrace(actual: actual)
        }
    }
    
    func testCaptureError() {
        let eventId = fixture.getSut().capture(error: error, scope: scope)
        
        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.error, actual.level)
            XCTAssertEqual(error.localizedDescription, actual.message)
            assertValidStacktrace(actual: actual)
        }
    }
    
    func testCaptureException() {
        let eventId = fixture.getSut().capture(exception: exception, scope: scope)
        
        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(SentryLevel.error, actual.level)
            XCTAssertEqual(exception.reason, actual.message)
            assertValidStacktrace(actual: actual)
        }
    }

    func testScopeIsNotNil() {
        let eventId = fixture.getSut().capture(message: message, scope: scope)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(environment, actual.environment)
        }
    }

    func testCaptureSession() {
        let session = SentrySession(releaseName: "release")
        fixture.getSut().capture(session: session)

        assertLastSentEnvelope { actual in
            XCTAssertEqual(1, actual.items.count)
            XCTAssertEqual("session", actual.items[0].header.type)
        }
    }

    func testCaptureEnvelope() {
        let envelope = SentryEnvelope(event: Event())
        let headerEventId = fixture.getSut().capture(envelope: envelope)

        assertLastSentEnvelope { actual in
            XCTAssertEqual(envelope.header.eventId, headerEventId)
            XCTAssertEqual(envelope, actual)
        }
    }

    func testBeforeSendReturnsNil_EventNotSent() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                nil
            }
        }).capture(message: message, scope: nil)

        assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_MessageNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let eventId = sut.capture(message: message, scope: nil)
        XCTAssertNil(eventId)
        assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_ExceptionNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let eventId = sut.capture(exception: exception, scope: nil)
        assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_ErrorNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let eventId = sut.capture(error: error, scope: nil)
        assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_EnvelopesAreSent() {
        let envelope = SentryEnvelope(event: Event())
        fixture.getSut(configureOptions: { options in
            options.enabled = false
        }).capture(envelope: envelope)

        assertLastSentEnvelope { actual in
            XCTAssertNotNil(actual)
        }
    }

    func testDistIsSet() {
        let dist = "dist"
        let eventId = fixture.getSut(configureOptions: { options in
            options.dist = dist
        }).capture(message: message, scope: nil)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(dist, actual.dist)
        }
    }

    func testEnvironmentIsSet() {
        let environment = "environment"
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = environment
        }).capture(message: message, scope: nil)

        XCTAssertNotNil(eventId)
        assertLastSentEvent { actual in
            XCTAssertEqual(environment, actual.environment)
        }
    }
    
    func assertEventNotSent(eventId: String?) {
        XCTAssertNil(fixture.transport.lastSentEvent)
        XCTAssertNil(eventId)
    }

    func assertLastSentEvent(assert: (Event) -> Void) {
        XCTAssertNotNil(fixture.transport.lastSentEvent)
        if let lastSentEvent = fixture.transport.lastSentEvent {
            assert(lastSentEvent)
        }
    }
    
    func assertLastSentEnvelope(assert: (SentryEnvelope) -> Void) {
        XCTAssertNotNil(fixture.transport.lastSentEnvelope)
        if let lastSentEnvelope = fixture.transport.lastSentEnvelope {
            assert(lastSentEnvelope)
        }
    }
    
    private func assertValidStacktrace(actual: Event) {
        let debugMetas = fixture.debugMetaBuilder.buildDebugMeta()
        XCTAssertEqual(debugMetas, actual.debugMeta ?? [])
        
        let threads = fixture.threadInspector.getCurrentThreadsSkippingFrames(3)
        
        XCTAssertNotNil(actual.threads)
        if let actualThreads = actual.threads {
            // TODO: implement isEqual and hash for Threads so we can compare them
            XCTAssertEqual(threads.count, actualThreads.count)
            XCTAssertEqual(threads[0].stacktrace?.frames.count, actualThreads[0].stacktrace?.frames.count)
        }
    }
}
