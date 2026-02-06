@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class DefaultTelemetrySchedulerTests: XCTestCase {

    // MARK: - Envelope Metadata Tests

    func testCapture_whenLogType_shouldCreateEnvelopeWithLogItemType() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.type, SentryEnvelopeItemTypes.log)
    }

    func testCapture_whenLogType_shouldCreateEnvelopeWithLogContentType() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.contentType, "application/vnd.sentry.items.log+json")
    }

    func testCapture_whenCalled_shouldCreateEnvelopeWithEmptyHeader() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.header.eventId, SentryEnvelopeHeader.empty().eventId)
        XCTAssertNil(envelope.header.traceContext)
    }

    func testCapture_whenCalled_shouldCreateEnvelopeWithSingleItem() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.items.count, 1)
    }

    // MARK: - Data Forwarding Tests

    func testCapture_whenCalledWithData_shouldPassDataToEnvelopeItem() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData(body: "test log data")

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.data, testData)
    }

    func testCapture_whenCalledWithCount_shouldPassCountAsNSNumber() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()
        let count = 42

        // -- Act --
        sut.capture(data: testData, count: count, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.itemCount, NSNumber(value: count))
    }

    // MARK: - Transport Interaction Tests

    func testCapture_whenCalled_shouldSendEnvelopeViaTransport() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)
    }

    func testCapture_whenCalledMultipleTimes_shouldSendMultipleEnvelopes() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData1 = try getLogData(body: "test1")
        let testData2 = try getLogData(body: "test2")

        // -- Act --
        sut.capture(data: testData1, count: 1, telemetryType: .log)
        sut.capture(data: testData2, count: 2, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 2)

        let envelope1 = try XCTUnwrap(transport.sendEnvelopeInvocations.invocations[0])
        let envelope2 = try XCTUnwrap(transport.sendEnvelopeInvocations.invocations[1])

        let item1 = try XCTUnwrap(envelope1.items.first)
        let item2 = try XCTUnwrap(envelope2.items.first)

        XCTAssertEqual(item1.data, testData1)
        XCTAssertEqual(item2.data, testData2)
    }

    // MARK: - Edge Cases Tests

    func testCapture_whenDataIsEmpty_shouldStillSendEnvelope() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let emptyData = Data()

        // -- Act --
        sut.capture(data: emptyData, count: 0, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.data, emptyData)
    }

    func testCapture_whenCountIsZero_shouldStillSendEnvelope() throws {
        // -- Arrange --
        let (sut, transport) = createScheduler()
        let testData = try getLogData()

        // -- Act --
        sut.capture(data: testData, count: 0, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.itemCount, NSNumber(value: 0))
    }

    // MARK: - Helper Methods

    private func createScheduler() -> (scheduler: DefaultTelemetryScheduler, transport: TestTelemetryProcessorTransport) {
        let transport = TestTelemetryProcessorTransport()
        let scheduler = DefaultTelemetryScheduler(transport: transport)
        return (scheduler, transport)
    }

    private func getLogData(body: String = "test log", level: SentryLog.Level = .info) throws -> Data {
        let log = SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId(uuidString: "12345678-1234-1234-1234-123456789012"),
            level: level,
            body: body,
            attributes: [:]
        )

        return try encodeToJSONData(data: log)
    }
}

// MARK: - Test Helpers

final class TestTelemetryProcessorTransport: SentryTelemetryProcessorTransport {
    let sendEnvelopeInvocations = Invocations<SentryEnvelope>()

    func sendEnvelope(envelope: SentryEnvelope) {
        sendEnvelopeInvocations.record(envelope)
    }
}
