@_spi(Private) @testable import Sentry
import XCTest

class SentryInternalEnvelopeApiTests: XCTestCase {

    private let mockHub = MockHub()
    private lazy var sut = SentryInternalEnvelopeApi(
        dependencies: MockEnvelopeDependencies(hub: mockHub)
    )

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

    func configureScope(_ callback: @escaping (Scope) -> Void) {}

    func storeEnvelope(_ envelope: SentryEnvelope) {
        storedEnvelopes.append(envelope)
    }

    func captureEnvelope(_ envelope: SentryEnvelope) {
        capturedEnvelopes.append(envelope)
    }
}

private struct MockEnvelopeDependencies: HubProvider {
    var hub: Hub
}
