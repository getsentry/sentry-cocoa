#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import XCTest

final class TestHubWrapperTests: XCTestCase {

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testCaptureEventWithScope_whenUsingNormalHubAPI_shouldRecordTypedValues() throws {
        // -- Arrange --
        let hub = TestHub(testClient: nil, scope: Scope())
        let event = Event()
        let scope = Scope()

        // -- Act --
        let eventId = hub.capture(event: event, scope: scope)

        // -- Assert --
        let invocation = try XCTUnwrap(hub.capturedEventsWithScopes.first)
        XCTAssertEqual(eventId, event.eventId)
        XCTAssertIdentical(invocation.event, event)
        XCTAssertIdentical(invocation.scope, scope)
        XCTAssertTrue(invocation.additionalEnvelopeItems.isEmpty)
    }

    func testSetTestSession_whenCapturingErrorEnvelope_shouldAttachSessionUpdate() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))
        let hub = TestHub(testClient: client, scope: Scope())
        hub.setTestSession()
        let envelope = TestConstants.envelope

        // -- Act --
        hub.capture(envelope)

        // -- Assert --
        let capturedEnvelope = try XCTUnwrap(client.captureEnvelopeInvocations.first)
        XCTAssertEqual(capturedEnvelope.items.count, envelope.items.count + 1)
        XCTAssertTrue(capturedEnvelope.items.contains { $0.header.type == "session" })
    }
}
