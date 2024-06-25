import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

final class SentryMetricsClientTests: XCTestCase {

    func testCaptureMetricsWithCounterMetric() throws {
        let testClient = try XCTUnwrap(TestClient(options: Options()))

        let sut = SentryMetricsClient(client: SentryStatsdClient(client: testClient))

        let metric = CounterMetric(first: 0.0, key: "app.start", unit: MeasurementUnitDuration.second, tags: ["sentry": "awesome"])
        let flushableBuckets: [BucketTimestamp: [Metric]] = [0: [metric]]
        
        let encodedMetricsData = encodeToStatsd(flushableBuckets: flushableBuckets)
        
        sut.capture(flushableBuckets: flushableBuckets)

        XCTAssertEqual(testClient.captureEnvelopeInvocations.count, 1)

        let envelope = try XCTUnwrap(testClient.captureEnvelopeInvocations.first)
        XCTAssertNotNil(envelope.header.eventId)

        XCTAssertEqual(envelope.items.count, 1)
        let envelopeItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(envelopeItem.header.type, SentryEnvelopeItemTypeStatsd)
        XCTAssertEqual(envelopeItem.header.contentType, "application/octet-stream")
        XCTAssertEqual(envelopeItem.header.length, UInt(encodedMetricsData.count))
        XCTAssertEqual(envelopeItem.data, encodedMetricsData)
    }

    func testCaptureMetricsWithNoMetrics() throws {
        let testClient = try XCTUnwrap(TestClient(options: Options()))

        let sut = SentryMetricsClient(client: SentryStatsdClient(client: testClient))

        let flushableBuckets: [BucketTimestamp: [CounterMetric]] = [:]
        sut.capture(flushableBuckets: flushableBuckets)

        XCTAssertEqual(testClient.captureEnvelopeInvocations.count, 0)
    }

}
