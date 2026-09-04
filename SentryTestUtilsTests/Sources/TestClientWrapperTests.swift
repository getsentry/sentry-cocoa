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
