import _SentryPrivate
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

final class SentryMetricsAPITests: XCTestCase {
    
    func testInitWithDisabled_AllOperationsAreNoOps() throws {
        let metricsClient = try TestMetricsClient()
        let sut = SentryMetricsAPI(enabled: false, client: metricsClient, currentDate: SentryCurrentDateProvider(), dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom())
        
        sut.increment(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.gauge(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.distribution(key: "some", value: 1.0, unit: .none, tags: ["yeah": "sentry"])
        sut.set(key: "some", value: 1, unit: .none, tags: ["yeah": "sentry"])
        
        sut.close()
        
        expect(metricsClient.captureInvocations.count) == 0
    }
    
    func testIncrement_EmitsIncrementMetric() throws {
        let metricsClient = try TestMetricsClient()
        let sut = SentryMetricsAPI(enabled: true, client: metricsClient, currentDate: SentryCurrentDateProvider(), dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom())
        
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
        expect(metric.tags) == ["yeah": "sentry"]
    }
    
    func testGauge_EmitsGaugeMetric() throws {
        let metricsClient = try TestMetricsClient()
        let sut = SentryMetricsAPI(enabled: true, client: metricsClient, currentDate: SentryCurrentDateProvider(), dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom())
        
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
        expect(metric.tags) == ["yeah": "sentry"]
    }
    
    func testDistribution_EmitsDistributionMetric() throws {
        let metricsClient = try TestMetricsClient()
        let sut = SentryMetricsAPI(enabled: true, client: metricsClient, currentDate: SentryCurrentDateProvider(), dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom())
        
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
        expect(metric.tags) == ["yeah": "sentry"]
    }
    
    func testSet_EmitsSetMetric() throws {
        let metricsClient = try TestMetricsClient()
        let sut = SentryMetricsAPI(enabled: true, client: metricsClient, currentDate: SentryCurrentDateProvider(), dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom())
        
        sut.set(key: "key", value: 1, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        sut.set(key: "key", value: 12, unit: MeasurementUnitFraction.percent, tags: ["yeah": "sentry"])
        
        sut.flush()
        
        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets.first?.value)
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first as? SetMetric)

        expect(metric.key) == "key"
        expect(metric.serialize()).to(contain(["1", "12"]))
        expect(metric.unit.unit) == MeasurementUnitFraction.percent.unit
        expect(metric.tags) == ["yeah": "sentry"]
    }

}
