@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryTelemetryProcessorFactoryTests: XCTestCase {

    // MARK: - Factory Tests

    func testGetProcessor_whenCalled_shouldReturnProcessor() {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let dependencies = createTestDependencies()

        // -- Act --
        let processor = SentryTelemetryProcessorFactory.getProcessor(transport: transport, dependencies: dependencies)

        // -- Assert --
        XCTAssertNotNil(processor)
    }

    func testGetProcessor_whenLogAddedAndFlushed_shouldSendViaTransport() throws {
        // -- Arrange --
        let transport = TestTelemetryProcessorTransport()
        let dependencies = createTestDependencies()
        let processor = SentryTelemetryProcessorFactory.getProcessor(transport: transport, dependencies: dependencies)
        let log = createTestLog(body: "End-to-end test")

        // -- Act --
        processor.add(log: log)
        _ = processor.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(transport.sendEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(transport.sendEnvelopeInvocations.first)
        XCTAssertEqual(envelope.items.count, 1)

        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(item.header.type, SentryEnvelopeItemTypes.log)
        XCTAssertEqual(item.header.contentType, "application/vnd.sentry.items.log+json")
    }

    // MARK: - Helper Methods

    private func createTestDependencies() -> SentryDependencyContainer {
        return SentryDependencyContainer.sharedInstance()
    }

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
