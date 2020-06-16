@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryClientTest: XCTestCase {

    private class Fixture {
        let transport = TestTransport()

        func getSut(configureOptions: (Options) -> Void = { _ in }) -> Client {
            var client: Client?
            do {
                let options = try Options(dict: [
                    "dsn": TestConstants.dsnAsString
                ])
                configureOptions(options)

                client = Client(options: options, andTransport: transport, andFileManager: try SentryFileManager(dsn: TestConstants.dsn))
            } catch {
                XCTFail("Options could not be created")
            }

            return client!
        }

        func getSutWithDisabledSdk() -> Client {
            return getSut(configureOptions: { options in
                options.enabled = false
            })
        }

        func assertEventNotSent(eventId: String?) {
            XCTAssertNil(transport.lastSentEvent)
            XCTAssertNil(eventId)
        }
    }

    private let message = "message"
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    func testCaptureMessage() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.attachStacktrace = true
        }).capture(message: message, scope: nil)

        let actual = fixture.transport.lastSentEvent!
        XCTAssertNotNil(eventId)
        XCTAssertEqual(SentryLevel.info, actual.level)
        XCTAssertEqual(message, actual.message)
        XCTAssertNotNil(actual.debugMeta)
        XCTAssertNotNil(actual.threads)
    }

    func testCaptureMessageWithoutStackrace() {
        let eventId = fixture.getSut().capture(message: message, scope: nil)

        let actual = fixture.transport.lastSentEvent!
        XCTAssertNotNil(eventId)
        XCTAssertEqual(SentryLevel.info, actual.level)
        XCTAssertEqual(message, actual.message)
        XCTAssertNil(actual.debugMeta)
        XCTAssertNil(actual.threads)
        XCTAssertNotNil(actual.dist)
    }

    func testScopeIsNotNil() {
        let environment = "environment"
        let scope = Scope()
        scope.setEnvironment(environment)

        let eventId = fixture.getSut().capture(message: message, scope: scope)

        XCTAssertNotNil(eventId)
        let actual = fixture.transport.lastSentEvent!
        XCTAssertEqual(environment, actual.environment)
    }

    func testCaptureSession() {
        let session = SentrySession(releaseName: "release")
        fixture.getSut().capture(session: session)

        let actual = fixture.transport.lastSentEnvelope!

        XCTAssertEqual(1, actual.items.count)
        XCTAssertEqual("session", actual.items[0].header.type)
    }

    func testCaptureEnvelope() {
        let envelope = SentryEnvelope(event: Event())
        let headerEventId = fixture.getSut().capture(envelope: envelope)
        let actual = fixture.transport.lastSentEnvelope!

        XCTAssertEqual(envelope.header.eventId, headerEventId)
        XCTAssertEqual(envelope, actual)
    }

    func testBeforeSendReturnsNil_EventNotSent() {
        let eventId = fixture.getSut(configureOptions: { options in
            options.beforeSend = { _ in
                nil
            }
        }).capture(message: message, scope: nil)

        fixture.assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_MessageNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let eventId = sut.capture(message: message, scope: nil)
        XCTAssertNil(eventId)
        fixture.assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_ExceptionNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)
        let eventId = sut.capture(exception: exception, scope: nil)
        fixture.assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_ErrorNotSent() {
        let sut = fixture.getSutWithDisabledSdk()
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let eventId = sut.capture(error: error, scope: nil)
        fixture.assertEventNotSent(eventId: eventId)
    }

    func testSdkDisabled_EnvelopesAreSent() {
        let envelope = SentryEnvelope(event: Event())
        fixture.getSut(configureOptions: { options in
            options.enabled = false
        }).capture(envelope: envelope)
        let actual = fixture.transport.lastSentEnvelope!
        XCTAssertNotNil(actual)
    }

    func testDistIsSet() {
        let dist = "dist"
        let eventId = fixture.getSut(configureOptions: { options in
            options.dist = dist
        }).capture(message: message, scope: nil)

        let actual = fixture.transport.lastSentEvent!
        XCTAssertNotNil(eventId)
        XCTAssertEqual(dist, actual.dist)
    }

    func testEnvironmentIsSet() {
        let environment = "environment"
        let eventId = fixture.getSut(configureOptions: { options in
            options.environment = environment
        }).capture(message: message, scope: nil)

        let actual = fixture.transport.lastSentEvent!
        XCTAssertNotNil(eventId)
        XCTAssertEqual(environment, actual.environment)
    }
}
