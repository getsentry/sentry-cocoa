#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class TestClientWrapperTests: XCTestCase {

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testCaptureSession_whenStartedByHub_shouldRecordTypedSession() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        options.releaseName = "1.0.0"
        let client = try XCTUnwrap(TestClient(options: options))
        let hub = SentryHubInternal(client: client, andScope: Scope())

        // -- Act --
        hub.startSession()

        // -- Assert --
        let session = try XCTUnwrap(client.captureSessionInvocations.first)
        XCTAssertEqual(client.captureSessionInvocations.count, 1)
        XCTAssertEqual(session.releaseName, options.releaseName)
    }

    func testCaptureEventWithScope_whenCapturedByHub_shouldRecordTypedValues() throws {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(TestClient(options: options))
        let hub = SentryHubInternal(client: client, andScope: Scope())
        let event = Event()
        let scope = Scope()

        // -- Act --
        let eventId = hub.capture(event: event, scope: scope)

        // -- Assert --
        let invocation = try XCTUnwrap(client.captureEventWithScopeInvocations.first)
        XCTAssertEqual(eventId, event.eventId)
        XCTAssertIdentical(invocation.event, event)
        XCTAssertIdentical(invocation.scope, scope)
        XCTAssertTrue(invocation.additionalEnvelopeItems.isEmpty)
    }

    func testInitialization_whenOptionsHaveWrongType_shouldReportFailure() {
        // -- Arrange --
        let options = NSObject()
        var client: TestClient?

        // -- Act --
        XCTExpectFailure("Invalid options must fail the test rather than silently returning nil") {
            client = TestClient(options: options)
        }

        // -- Assert --
        XCTAssertNil(client)
    }

    func testCaptureSession_whenBridgeReceivesWrongType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))

        // -- Act --
        XCTExpectFailure("Invalid sessions must fail the test") {
            client.wrapper_capture(session: NSObject())
        }

        // -- Assert --
        XCTAssertEqual(client.captureSessionInvocations.count, 0)
    }

    func testCaptureEvent_whenBridgeReceivesWrongItemType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))
        let event = Event()
        var eventId: SentryId?

        // -- Act --
        XCTExpectFailure("Invalid envelope items must fail the test") {
            eventId = client.wrapper_capture(event: event, scope: Scope(), additionalEnvelopeItems: [NSObject()])
        }

        // -- Assert --
        XCTAssertEqual(eventId, event.eventId)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 0)
    }

    func testCaptureFatalEvent_whenBridgeReceivesWrongSessionType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))
        let event = Event()
        var eventId: SentryId?

        // -- Act --
        XCTExpectFailure("Invalid fatal-event sessions must fail the test") {
            eventId = client.wrapper_captureFatalEvent(event, session: NSObject(), scope: Scope())
        }

        // -- Assert --
        XCTAssertEqual(eventId, event.eventId)
        XCTAssertEqual(client.captureFatalEventWithSessionInvocations.count, 0)
    }

    func testCaptureFeedback_whenBridgeReceivesWrongType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))

        // -- Act --
        XCTExpectFailure("Invalid feedback must fail the test") {
            client.wrapper_capture(feedback: NSObject(), scope: Scope())
        }

        // -- Assert --
        XCTAssertEqual(client.captureFeedbackInvocations.count, 0)
    }

    func testCaptureEnvelope_whenBridgeReceivesWrongType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))

        // -- Act --
        XCTExpectFailure("Invalid captured envelopes must fail the test") {
            client.wrapper_capture(envelope: NSObject())
        }

        // -- Assert --
        XCTAssertEqual(client.captureEnvelopeInvocations.count, 0)
    }

    func testStoreEnvelope_whenBridgeReceivesWrongType_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))

        // -- Act --
        XCTExpectFailure("Invalid stored envelopes must fail the test") {
            client.wrapper_store(envelope: NSObject())
        }

        // -- Assert --
        XCTAssertEqual(client.storedEnvelopeInvocations.count, 0)
    }

    func testRecordLostEvent_whenBridgeReceivesInvalidRawValues_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))
        let category = SentryDataCategory.error.rawValue
        let reason = SentryDiscardReason.sampleRate.rawValue

        // -- Act --
        XCTExpectFailure("Invalid categories must fail the test") {
            client.wrapper_recordLostEvent(UInt.max, reason: reason)
        }
        XCTExpectFailure("Invalid reasons must fail the test") {
            client.wrapper_recordLostEvent(category, reason: UInt.max)
        }

        // -- Assert --
        XCTAssertEqual(client.recordLostEvents.count, 0)
    }

    func testRecordLostEventWithQuantity_whenBridgeReceivesInvalidRawValues_shouldReportFailure() throws {
        // -- Arrange --
        let client = try XCTUnwrap(TestClient(options: Options.noIntegrations()))
        let category = SentryDataCategory.error.rawValue
        let reason = SentryDiscardReason.sampleRate.rawValue

        // -- Act --
        XCTExpectFailure("Invalid categories must fail the test") {
            client.wrapper_recordLostEvent(UInt.max, reason: reason, quantity: 2)
        }
        XCTExpectFailure("Invalid reasons must fail the test") {
            client.wrapper_recordLostEvent(category, reason: UInt.max, quantity: 2)
        }

        // -- Assert --
        XCTAssertEqual(client.recordLostEventsWithQauntity.count, 0)
    }

    func testInitialization_whenUsingSwiftSubclass_shouldUseExistingOverrideSeam() throws {
        // -- Arrange --
        final class ClientSubclass: TestClient {
            private(set) var getTelemetryProcessorCalled = false

            override func getTelemetryProcessor() -> Any {
                getTelemetryProcessorCalled = true
                return NSObject()
            }
        }

        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        let client = try XCTUnwrap(ClientSubclass(options: options))

        // -- Act --
        _ = client.getTelemetryProcessor()

        // -- Assert --
        XCTAssertTrue(client.getTelemetryProcessorCalled)
    }
}
