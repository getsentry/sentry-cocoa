import _SentryPrivate
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

final class SentryMetricsAPITests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    private func getSut(enabled: Bool = true) throws -> (SentryMetricsAPI, TestMetricsClient, TestCurrentDateProvider, TestHub, Options) {
        
        let metricsClient = try TestMetricsClient()
        let currentDate = TestCurrentDateProvider()
        let sut = SentryMetricsAPI(enabled: enabled, client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), beforeEmitMetric: nil)
        
        SentryDependencyContainer.sharedInstance().dateProvider = currentDate
        
        let options = Options()
        options.enableMetrics = true
        
        let testClient = try XCTUnwrap(TestClient(options: options))
        let testHub = TestHub(client: testClient, andScope: Scope())
        
        sut.setDelegate(testHub as? SentryMetricsAPIDelegate)
        
        return (sut, metricsClient, currentDate, testHub, options)
    }
    
    func testInitWithDisabled_AllOperationsAreNoOps() throws {
        let (sut, metricsClient, _, _, _) = try getSut(enabled: false)
        
        sut.increment(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.gauge(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.distribution(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.set(key: "some", value: "value", unit: .none, tags: ["yeah": "sentry"])
        
        sut.close()
        
        expect(metricsClient.captureInvocations.count) == 0
    }
    
    func testIncrement_EmitsIncrementMetric() throws {
        let (sut, metricsClient, _, _, _) = try getSut()
        let delegate = TestSentryMetricsAPIDelegate()
        sut.setDelegate(delegate)
        
        sut.increment(key: "key", value: 1.0, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        
        sut.flush()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)
        
        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? CounterMetric)
        
        expect(metric.key) == "key"
        expect(metric.serialize()).to(contain(["1.0"]))
        expect(metric.unit.unit) == MeasurementUnitFraction.percent.unit
        expect(metric.tags) == ["yeah": "sentry", "some": "tag"]
    }
    
    func testGauge_EmitsGaugeMetric() throws {
        let (sut, metricsClient, _, _, _) = try getSut()
        let delegate = TestSentryMetricsAPIDelegate()
        sut.setDelegate(delegate)
        
        sut.gauge(key: "key", value: 1.0, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        
        sut.flush()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)
        
        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? GaugeMetric)
        
        expect(metric.key) == "key"
        expect(metric.serialize()) == ["1.0", "1.0", "1.0", "1.0", "1"]
        expect(metric.unit.unit) == MeasurementUnitFraction.percent.unit
        expect(metric.tags) == ["yeah": "sentry", "some": "tag"]
    }
    
    func testDistribution_EmitsDistributionMetric() throws {
        let (sut, metricsClient, _, _, _) = try getSut()
        let delegate = TestSentryMetricsAPIDelegate()
        sut.setDelegate(delegate)
        
        sut.distribution(key: "key", value: 1.0, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        sut.distribution(key: "key", value: 12.0, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        
        sut.flush()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)
        
        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? DistributionMetric)
        
        expect(metric.key) == "key"
        expect(metric.serialize()) == ["1.0", "12.0"]
        expect(metric.unit.unit) == MeasurementUnitFraction.percent.unit
        expect(metric.tags) == ["yeah": "sentry", "some": "tag"]
    }
    
    func testSet_EmitsSetMetric() throws {
        let (sut, metricsClient, _, _, _) = try getSut()
        let delegate = TestSentryMetricsAPIDelegate()
        sut.setDelegate(delegate)
        
        sut.set(key: "key", value: "value1", unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        sut.set(key: "key", value: "value1", unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        sut.set(key: "key", value: "value12", unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        
        sut.flush()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)
        
        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? SetMetric)
        
        expect(metric.key) == "key"
        expect(metric.serialize()).to(contain(["2445898635", "2725604442"]))
        expect(metric.unit.unit) == MeasurementUnitFraction.percent.unit
        expect(metric.tags) == ["yeah": "sentry", "some": "tag"]
    }
    
    func testTiming_WhenNoCurrentSpan_NoSpanCreatedAndNoMetricEmitted() throws {
        let (sut, metricsClient, _, _, _) = try getSut()
        let delegate = TestSentryMetricsAPIDelegate()
        sut.setDelegate(delegate)
        
        let errorMessage = "It's broken"
        do {
            try sut.timing(key: "key") {
                throw MetricsAPIError.runtimeError(errorMessage)
            }
        } catch MetricsAPIError.runtimeError(let actualErrorMessage) {
            expect(actualErrorMessage) == errorMessage
        }
        
        expect(metricsClient.captureInvocations.count) == 0
    }
    
    func testTiming_WithCurrentSpan_CapturesGaugeMetric() throws {
        let (sut, metricsClient, currentDate, testHub, options) = try getSut()
        
        let transaction = testHub.startTransaction(name: "hello", operation: "operation", bindToScope: true)
        
        let errorMessage = "It's broken"
        do {
            try sut.timing(key: "key", tags: ["some": "tag"]) {
                currentDate.setDate(date: currentDate.date().addingTimeInterval(1.0))
                throw MetricsAPIError.runtimeError(errorMessage)
            }
        } catch MetricsAPIError.runtimeError(let actualErrorMessage) {
            expect(actualErrorMessage) == errorMessage
        }
        
        sut.flush()
        transaction.finish()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)
        
        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? DistributionMetric)
        
        expect(metric.key) == "key"
        expect(metric.serialize()) == ["1.0"]
        expect(metric.unit.unit) == MeasurementUnitDuration.second.unit
        expect(metric.tags) == ["some": "tag", "release": options.releaseName, "environment": options.environment]
    }
    
    func testTiming_WithCurrentSpan_CreatesSpanWithMetricsSummary() throws {
        let (sut, _, currentDate, testHub, options) = try getSut()
        
        let transaction = testHub.startTransaction(name: "hello", operation: "operation", bindToScope: true)
        
        sut.timing(key: "key", tags: ["some": "tag"]) {
            currentDate.setDate(date: currentDate.date().addingTimeInterval(1.0))
        }
        
        transaction.finish()
        
        expect(testHub.capturedTransactionsWithScope.count) == 1
        let serializedTransaction = try XCTUnwrap(testHub.capturedTransactionsWithScope.first?.transaction)
        expect(serializedTransaction.count) != 0
        
        let spans = try XCTUnwrap(serializedTransaction["spans"] as? [[String: Any]])
        expect(spans.count) == 1
        let span = try XCTUnwrap(spans.first)
        
        expect(span["op"] as? String) == "metric.timing"
        expect(span["description"] as? String) == "key"
        expect(span["origin"] as? String) == "manual"
        expect(span["start_timestamp"] as? Int) == 978_307_200
        expect(span["timestamp"] as? Int) == 978_307_201
        expect(span["parent_span_id"] as? String) == transaction.spanId.sentrySpanIdString
        expect(span["tags"] as? [String: String]) == ["some": "tag", "release": options.releaseName, "environment": options.environment]
        
        let metricsSummary = try XCTUnwrap(span["_metrics_summary"] as? [String: [[String: Any]]])
        expect(metricsSummary.count) == 1
        
        let bucket = try XCTUnwrap(metricsSummary["d:key@second"] )
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        expect(metric["min"] as? Double) == 1.0
        expect(metric["max"] as? Double) == 1.0
        expect(metric["count"] as? Int) == 1
        expect(metric["sum"] as? Double) == 1.0
    }
    
    enum MetricsAPIError: Error {
        case runtimeError(String)
    }
}

class TestSentryMetricsAPIDelegate: SentryMetricsAPIDelegate {
    var currentSpan: SentrySpan?
    
    func getDefaultTagsForMetrics() -> [String: String] {
        return ["some": "tag", "yeah": "not-taken"]
    }
    
    func getLocalMetricsAggregator() -> Sentry.LocalMetricsAggregator? {
        return currentSpan?.getLocalMetricsAggregator()
    }
    
    func getCurrentSpan() -> (any Span)? {
        return currentSpan
    }
    
    func getLocalMetricsAggregator(span: any Span) -> Sentry.LocalMetricsAggregator? {
        return (span as? SentrySpan)?.getLocalMetricsAggregator()
    }
}
