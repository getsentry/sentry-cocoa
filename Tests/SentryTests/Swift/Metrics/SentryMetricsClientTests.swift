import _SentryPrivate
import Nimble
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

        expect(testClient.captureEnvelopeInvocations.count) == 1

        let envelope = try XCTUnwrap(testClient.captureEnvelopeInvocations.first)
        expect(envelope.header.eventId) != nil

        expect(envelope.items.count) == 1
        let envelopeItem = try XCTUnwrap(envelope.items.first)
        expect(envelopeItem.header.type) == SentryEnvelopeItemTypeStatsd
        expect(envelopeItem.header.contentType) == "application/octet-stream"
        expect(envelopeItem.header.length) == UInt(encodedMetricsData.count)
        expect(envelopeItem.data) == encodedMetricsData
    }

    func testCaptureMetricsWithNoMetrics() throws {
        let testClient = try XCTUnwrap(TestClient(options: Options()))

        let sut = SentryMetricsClient(client: SentryStatsdClient(client: testClient))

        let flushableBuckets: [BucketTimestamp: [CounterMetric]] = [:]
        sut.capture(flushableBuckets: flushableBuckets)

        expect(testClient.captureEnvelopeInvocations.count) == 0
    }

}
