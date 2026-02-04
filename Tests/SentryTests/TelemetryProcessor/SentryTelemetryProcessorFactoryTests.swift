@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryTelemetryProcessorFactoryTests: XCTestCase {

    // MARK: - Factory Tests

    func testGetProcessor_whenCalled_shouldReturnProcessor() {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()

        // -- Act --
        let processor = SentryTelemetryProcessorFactory.getProcessor(transport: transport)

        // -- Assert --
        XCTAssertNotNil(processor)
    }

    func testGetProcessor_whenLogAddedAndFlushed_shouldSendViaTransport() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let processor = SentryTelemetryProcessorFactory.getProcessor(transport: transport)
        let log = createTestLog(body: "End-to-end test")

        // -- Act --
        processor.add(log: log)
        _ = processor.flush()

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.items.count, 1)

        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.type, SentryEnvelopeItemTypes.log)
        XCTAssertEqual(item.header.contentType, "application/vnd.sentry.items.log+json")
    }

    // MARK: - Helper Methods

    private func createTestLog(
        body: String,
        level: SentryLog.Level = .info
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: [:]
        )
    }
}
