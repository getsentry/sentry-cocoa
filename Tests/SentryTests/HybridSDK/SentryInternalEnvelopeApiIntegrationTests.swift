@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryInternalEnvelopeApiIntegrationTests: XCTestCase {

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testEnvelope_shouldBeAccessible() {
        // -- Arrange --
        startSdk()

        // -- Act --
        let envelope = SentrySDK.internal.envelope

        // -- Assert --
        XCTAssertNotNil(envelope)
    }

    // MARK: - store

    func testStore_shouldForwardToClient() {
        // -- Arrange --
        let client = TestClient(options: Options())
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        let envelope = TestConstants.envelope

        // -- Act --
        SentrySDK.internal.envelope.store(envelope)

        // -- Assert --
        XCTAssertEqual(1, client?.storedEnvelopeInvocations.count)
        XCTAssertEqual(envelope, client?.storedEnvelopeInvocations.first)
    }

    func testStore_whenUnhandledException_shouldMarkSessionAsCrashedAndNotStartNewSession() throws {
        // -- Arrange --
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        hub.setTestSession()
        let sessionToBeCrashed = hub.session

        let envelope = makeUnhandledExceptionEnvelope()

        // -- Act --
        SentrySDK.internal.envelope.store(envelope)

        // -- Assert --
        let storedEnvelope = client?.storedEnvelopeInvocations.first
        let attachedSessionData = try XCTUnwrap(XCTUnwrap(storedEnvelope).items.last?.data)
        let attachedSession = try XCTUnwrap(try JSONSerialization.jsonObject(with: attachedSessionData) as? [String: Any])

        XCTAssertEqual(0, hub.startSessionInvocations)
        XCTAssertEqual(sessionToBeCrashed!.sessionId.uuidString, try XCTUnwrap(attachedSession["sid"] as? String))
        XCTAssertEqual("crashed", try XCTUnwrap(attachedSession["status"] as? String))
    }

    // MARK: - capture

    func testCapture_shouldForwardToClient() {
        // -- Arrange --
        let client = TestClient(options: Options())
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        let envelope = TestConstants.envelope

        // -- Act --
        SentrySDK.internal.envelope.capture(envelope)

        // -- Assert --
        XCTAssertEqual(1, client?.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope, client?.captureEnvelopeInvocations.first)
    }

    func testCapture_whenUnhandledException_shouldMarkSessionAsCrashedAndStartNewSession() throws {
        // -- Arrange --
        let client = TestClient(options: Options())
        let hub = TestHub(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        hub.setTestSession()
        let sessionToBeCrashed = hub.session

        let envelope = makeUnhandledExceptionEnvelope()

        // -- Act --
        SentrySDK.internal.envelope.capture(envelope)

        // -- Assert --
        let capturedEnvelope = client?.captureEnvelopeInvocations.first
        let attachedSessionData = try XCTUnwrap(XCTUnwrap(capturedEnvelope).items.last?.data)
        let attachedSession = try XCTUnwrap(try JSONSerialization.jsonObject(with: attachedSessionData) as? [String: Any])

        XCTAssertEqual(1, hub.startSessionInvocations)
        XCTAssertEqual(sessionToBeCrashed!.sessionId.uuidString, try XCTUnwrap(attachedSession["sid"] as? String))
        XCTAssertEqual("crashed", try XCTUnwrap(attachedSession["status"] as? String))
    }

    // MARK: - deserialize

    func testDeserialize_whenValidData_shouldReturnEnvelope() {
        // -- Arrange --
        let data = Data("{}\n{\"length\":0,\"type\":\"attachment\"}\n".utf8)

        // -- Act --
        let result = SentrySDK.internal.envelope.deserialize(from: data)

        // -- Assert --
        XCTAssertNotNil(result)
    }

    func testDeserialize_whenLengthExceedsData_shouldReturnNil() {
        // -- Arrange --
        let data = Data("{}\n{\"length\":1,\"type\":\"attachment\"}\n".utf8)

        // -- Act --
        let result = SentrySDK.internal.envelope.deserialize(from: data)

        // -- Assert --
        XCTAssertNil(result)
    }

    func testDeserialize_whenEmptyData_shouldReturnNil() {
        // -- Act --
        let result = SentrySDK.internal.envelope.deserialize(from: Data())

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func startSdk() {
        let dsn = TestConstants.dsnForTestCase(type: SentryInternalEnvelopeApiIntegrationTests.self)
        SentrySDK.start { options in
            options.dsn = dsn
            options.removeAllIntegrations()
        }
    }

    private func makeUnhandledExceptionEnvelope() -> SentryEnvelope {
        let event = Event()
        event.message = SentryMessage(formatted: "Test Event with unhandled exception")
        event.level = .error
        event.exceptions = [TestData.exception]
        event.exceptions?.first?.mechanism?.handled = false
        return SentryEnvelope(event: event)
    }
}
