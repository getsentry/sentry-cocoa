@_spi(Private) @testable import Sentry
import XCTest

class SentryInternalEnvelopeApiTests: XCTestCase {

    private let mockHub = MockHub()
    private lazy var sut = SentryInternalEnvelopeApi(
        dependencies: MockEnvelopeDependencies(hub: mockHub)
    )

    // MARK: - store

    func testStore_shouldForwardToHub() {
        // -- Arrange --
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: SentryId()), items: [])

        // -- Act --
        sut.store(envelope)

        // -- Assert --
        XCTAssertEqual([envelope], mockHub.storedEnvelopes)
    }

    // MARK: - capture

    func testCapture_shouldForwardToHub() {
        // -- Arrange --
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: SentryId()), items: [])

        // -- Act --
        sut.capture(envelope)

        // -- Assert --
        XCTAssertEqual([envelope], mockHub.capturedEnvelopes)
    }

    // MARK: - captureNonTerminating

    func testCaptureNonTerminating_shouldForwardToHub() {
        // -- Arrange --
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: SentryId()), items: [])

        // -- Act --
        sut.captureNonTerminating(envelope)

        // -- Assert --
        XCTAssertEqual([envelope], mockHub.capturedNonTerminatingEnvelopes)
        XCTAssertTrue(mockHub.capturedEnvelopes.isEmpty)
    }

    // MARK: - updateSessionForDroppedEventNonTerminating

    func testUpdateSessionForDroppedEventNonTerminating_shouldForwardToHubWithoutCapturing() {
        // -- Act --
        sut.updateSessionForDroppedEventNonTerminating(unhandled: true)
        sut.updateSessionForDroppedEventNonTerminating(unhandled: false)

        // -- Assert --
        XCTAssertEqual([true, false], mockHub.updateSessionForDroppedEventNonTerminatingInvocations)
        XCTAssertTrue(mockHub.capturedEnvelopes.isEmpty)
        XCTAssertTrue(mockHub.capturedNonTerminatingEnvelopes.isEmpty)
    }

    // MARK: - deserialize

    func testDeserialize_whenValidData_shouldReturnEnvelope() throws {
        // -- Arrange --
        let envelopeHeader = SentryEnvelopeHeader(id: SentryId())
        let itemData = Data("test".utf8)
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(itemData.count))
        let item = SentryEnvelopeItem(header: itemHeader, data: itemData)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: item)
        guard let serialized = SentrySerializationSwift.data(with: envelope) else {
            return XCTFail("Failed to serialize envelope")
        }

        // -- Act --
        let result = sut.deserialize(from: serialized)

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.items.count, 1)
    }

    func testDeserialize_whenInvalidData_shouldReturnNil() {
        // -- Act --
        let result = sut.deserialize(from: Data())

        // -- Assert --
        XCTAssertNil(result)
    }
}

private class MockHub: Hub {
    var storedEnvelopes: [SentryEnvelope] = []
    var capturedEnvelopes: [SentryEnvelope] = []
    var capturedNonTerminatingEnvelopes: [SentryEnvelope] = []
    var updateSessionForDroppedEventNonTerminatingInvocations: [Bool] = []

    func configureScope(_ callback: @escaping (Scope) -> Void) {}

    func storeEnvelope(_ envelope: SentryEnvelope) {
        storedEnvelopes.append(envelope)
    }

    func captureEnvelope(_ envelope: SentryEnvelope) {
        capturedEnvelopes.append(envelope)
    }

    func captureNonTerminatingEnvelope(_ envelope: SentryEnvelope) {
        capturedNonTerminatingEnvelopes.append(envelope)
    }

    func updateSessionForDroppedEventNonTerminating(unhandled: Bool) {
        updateSessionForDroppedEventNonTerminatingInvocations.append(unhandled)
    }

    func captureErrorEvent(event: Event) {}
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
    var currentOptions: Options? { options }
    var options: Options { Options() }
    var scope: Scope { Scope() }
}

private struct MockEnvelopeDependencies: HubProvider {
    var hub: Hub
}
