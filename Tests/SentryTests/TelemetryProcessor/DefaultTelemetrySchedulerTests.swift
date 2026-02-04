@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class DefaultTelemetrySchedulerTests: XCTestCase {

    // MARK: - Envelope Metadata Tests

    func testCapture_whenLogType_shouldCreateEnvelopeWithLogItemType() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.type, SentryEnvelopeItemTypes.log)
    }

    func testCapture_whenLogType_shouldCreateEnvelopeWithLogContentType() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.contentType, "application/vnd.sentry.items.log+json")
    }

    func testCapture_whenCalled_shouldCreateEnvelopeWithEmptyHeader() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.header.eventId, SentryEnvelopeHeader.empty().eventId)
        XCTAssertNil(envelope.header.traceContext)
    }

    func testCapture_whenCalled_shouldCreateEnvelopeWithSingleItem() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.items.count, 1)
    }

    // MARK: - Data Forwarding Tests

    func testCapture_whenCalledWithData_shouldPassDataToEnvelopeItem() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test log data".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.data, testData)
    }

    func testCapture_whenCalledWithCount_shouldPassCountAsNSNumber() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)
        let count = 42

        // -- Act --
        sut.capture(data: testData, count: count, telemetryType: .log)

        // -- Assert --
        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.itemCount, NSNumber(value: count))
    }

    // MARK: - Transport Interaction Tests

    func testCapture_whenCalled_shouldSendEnvelopeViaTransport() {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 1, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)
    }

    func testCapture_whenCalledMultipleTimes_shouldSendMultipleEnvelopes() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData1 = Data("test1".utf8)
        let testData2 = Data("test2".utf8)

        // -- Act --
        sut.capture(data: testData1, count: 1, telemetryType: .log)
        sut.capture(data: testData2, count: 2, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 2)

        let envelope1 = try XCTUnwrap(transport.sendEnvelopeInvocations.invocations[0])
        let envelope2 = try XCTUnwrap(transport.sendEnvelopeInvocations.invocations[1])

        XCTAssertEqual(envelope1.items.first?.data, testData1)
        XCTAssertEqual(envelope2.items.first?.data, testData2)
    }

    // MARK: - Edge Cases Tests

    func testCapture_whenDataIsEmpty_shouldStillSendEnvelope() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
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
        let transport = TestTelemetryProcessorTransport()
        let sut = DefaultTelemetryScheduler(transport: transport)
        let testData = Data("test".utf8)

        // -- Act --
        sut.capture(data: testData, count: 0, telemetryType: .log)

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.itemCount, NSNumber(value: 0))
    }
}

// MARK: - Test Helpers

final class TestTelemetryProcessorTransport: SentryTelemetryProcessorTransport {
    let sendEnvelopeInvocations = Invocations<SentryEnvelope>()

    func sendEnvelope(envelope: SentryEnvelope) {
        sendEnvelopeInvocations.record(envelope)
    }
}
