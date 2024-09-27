@testable import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

final class BucketMetricsAggregatorTests: XCTestCase {

    private func getSut(totalMaxWeight: UInt = 4, flushShift: Double = 0.0, dispatchQueue: SentryDispatchQueueWrapper = TestSentryDispatchQueueWrapper()) throws -> (BucketMetricsAggregator, TestCurrentDateProvider, TestMetricsClient) {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()
        let random = TestRandom(value: flushShift)

        return (BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: dispatchQueue, random: random, totalMaxWeight: totalMaxWeight, flushInterval: 10.0, flushTolerance: 1.0), currentDate, metricsClient)
    }

    func testSameMetricAggregated_WhenInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut()

        sut.distribution( key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        currentDate.setDate(date: currentDate.date().addingTimeInterval(9.99))
        sut.distribution(key: "key", value: 1.1, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        XCTAssertEqual(bucket.count, 1)
        let counterMetric = try XCTUnwrap(bucket.first as? DistributionMetric)

        XCTAssertEqual(counterMetric.key, "key")
        XCTAssert(counterMetric.serialize().contains("1.0"))
        XCTAssert(counterMetric.serialize().contains("1.1"))
        XCTAssertEqual(counterMetric.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(counterMetric.tags, [:])
    }

    func testFlushShift_MetricsUsuallyInSameBucket_AreInDifferent() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 100, flushShift: 0.1)

        sut.gauge(key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 9.99))
        sut.gauge(key: "key", value: -1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // Not flushing yet
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 1.0))
        sut.flush(force: false)
        XCTAssertEqual(metricsClient.captureInvocations.count, 0)

        // This ends up in a different bucket
        sut.gauge(key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // Now we pass the flush shift threshold
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 0.01))
        sut.flush(force: false)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let previousBucketTimestamp = currentDate.bucketTimestamp - 10
        let bucket = try XCTUnwrap(buckets[previousBucketTimestamp])
        XCTAssertEqual(bucket.count, 1)
        let metric = try XCTUnwrap(bucket.first as? GaugeMetric)

        XCTAssertEqual(metric.key, "key")
        XCTAssertEqual(metric.serialize(), ["-1.0", "-1.0", "1.0", "0.0", "2"])
        XCTAssertEqual(metric.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(metric.tags, [:])
    }

    func testDifferentMetrics_NotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut()

        sut.set( key: "key1", value: 1, unit: MeasurementUnitDuration.day, tags: ["some": "tag", "and": "another-one"])
        sut.set(key: "key2", value: 2, unit: MeasurementUnitDuration.day, tags: ["and": "another-one", "some": "tag"])

        sut.flush(force: true)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        XCTAssertEqual(bucket.count, 2)

        let metric1 = try XCTUnwrap(bucket.first { $0.key == "key1" } as? SetMetric)
        XCTAssertEqual(metric1.key, "key1")
        XCTAssertEqual(metric1.serialize(), ["1"])
        XCTAssertEqual(metric1.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(metric1.tags, ["some": "tag", "and": "another-one"])

        let metric2 = try XCTUnwrap(bucket.first { $0.key == "key2" } as? SetMetric)
        XCTAssertEqual(metric2.key, "key2")
        XCTAssertEqual(metric2.serialize(), ["2"])
        XCTAssertEqual(metric2.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(metric2.tags, ["some": "tag", "and": "another-one"])
    }

    func testSameMetricDifferentTag_NotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut()

        sut.increment(key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["some": "tag"])
        sut.increment(key: "key", value: 2.0, unit: MeasurementUnitDuration.day, tags: ["some": "other-tag"])

        sut.flush(force: true)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        XCTAssertEqual(bucket.count, 2)

        let counterMetric1 = try XCTUnwrap(bucket.first { $0.tags == ["some": "tag"] } as? CounterMetric)
        XCTAssertEqual(counterMetric1.key, "key")
        XCTAssertEqual(counterMetric1.serialize(), ["1.0"])
        XCTAssertEqual(counterMetric1.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(counterMetric1.tags, ["some": "tag"])

        let counterMetric2 = try XCTUnwrap(bucket.first { $0.tags == ["some": "other-tag"] } as? CounterMetric)
        XCTAssertEqual(counterMetric2.key, "key")
        XCTAssertEqual(counterMetric2.serialize(), ["2.0"])
        XCTAssertEqual(counterMetric2.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(counterMetric2.tags, ["some": "other-tag"])
    }

    func testSameMetricNotAggregated_WhenNotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 5)

        sut.increment(key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 10.0))
        sut.increment(key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        XCTAssertEqual(buckets.count, 2)

        let bucket1 = try XCTUnwrap(buckets.values.first)
        XCTAssertEqual(bucket1.count, 1)
        let counterMetric1 = try XCTUnwrap(bucket1.first as? CounterMetric)

        XCTAssertEqual(counterMetric1.key, "key")
        XCTAssertEqual(counterMetric1.serialize(), ["1.0"])
        XCTAssertEqual(counterMetric1.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(counterMetric1.tags, [:])

        let bucket2 = try XCTUnwrap(Array(buckets.values).last)
        let counterMetric2 = try XCTUnwrap(bucket2.first as? CounterMetric)

        XCTAssertEqual(counterMetric2.key, "key")
        XCTAssertEqual(counterMetric2.serialize(), ["1.0"])
        XCTAssertEqual(counterMetric2.unit.unit, MeasurementUnitDuration.day.unit)
        XCTAssertEqual(counterMetric2.tags, [:])
    }

    func testCallFlushWhenOverweight() throws {
        let (sut, _, metricsClient) = try getSut(totalMaxWeight: 3, dispatchQueue: SentryDispatchQueueWrapper())

        let expectation = expectation(description: "Before capture block called")
        metricsClient.afterRecordingCaptureInvocationBlock = {
            XCTAssertFalse(Thread.isMainThread, "Flush must be called on a background thread, but was called on the main thread.")
            expectation.fulfill()
        }

        sut.increment(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.increment(key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
    }
    
    func testConvenienceInit_SetsCorrectMaxWeight() throws {
        let metricsClient = try TestMetricsClient()
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: TestCurrentDateProvider(), dispatchQueue: TestSentryDispatchQueueWrapper(), random: SentryRandom())

        for i in 0..<998 {
            sut.increment(key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        }
        
        // Total weight is now 999 because the bucket counts for one
        // So nothing should be sent
        XCTAssertEqual(metricsClient.captureInvocations.count, 0)
        
        // Now we pass the 1000 threshold
        sut.increment(key: "another key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
    }

    func testFlushOnlyWhenNeeded() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 5)

        sut.increment(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: false)
        XCTAssertEqual(metricsClient.captureInvocations.invocations.count, 0)

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 9.99))
        sut.flush(force: false)
        XCTAssertEqual(metricsClient.captureInvocations.invocations.count, 0)

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 0.01))
        sut.increment(key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: false)
        let buckets1 = try XCTUnwrap(metricsClient.captureInvocations.first)
        XCTAssertEqual(buckets1.count, 1)
        XCTAssertEqual(buckets1.values.count, 1)

        // Key2 wasn't flushed. We increment it to 2.0
        sut.increment( key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // The weight should be 2 now, so we need to add 3 more to trigger a flush
        sut.increment(key: "key3", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.increment(key: "key4", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.increment(key: "key5", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        XCTAssertEqual(metricsClient.captureInvocations.count, 2)
        let buckets2 = try XCTUnwrap(try XCTUnwrap(metricsClient.captureInvocations.invocations.element(at: 1)))

        XCTAssertEqual(buckets2.count, 1)
        let bucket = try XCTUnwrap(buckets2.first)

        // All 4 metrics should be in the bucket
        XCTAssertEqual(bucket.value.count, 4)

        // Check that key2 was incremented
        let counterMetric = try XCTUnwrap(bucket.value.first { $0.key == "key2" } as? CounterMetric)
        XCTAssertEqual(counterMetric.serialize(), ["2.0"])
    }
    
    func testWeightWithMultipleDifferent() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 4)
        
        sut.distribution(key: "key", value: 1.0, unit: .none, tags: [:])
        sut.distribution(key: "key", value: 1.0, unit: .none, tags: [:])
        
        // Weight should be 3, no flush yet
        sut.flush(force: false)
        XCTAssertEqual(metricsClient.captureInvocations.count, 0)
        
        // Time passed, must flush
        currentDate.setDate(date: currentDate.date().addingTimeInterval(10.0))
        sut.flush(force: false)
        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        
        sut.distribution(key: "key", value: 1.0, unit: .none, tags: [:])
        sut.distribution(key: "key", value: 1.0, unit: .none, tags: [:])
        sut.distribution(key: "key", value: 1.0, unit: .none, tags: [:])
        
        // Reached overweight, must flush
        XCTAssertEqual(metricsClient.captureInvocations.count, 2)
    }

    func testInitStartsRepeatingTimer() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        // Start the flush timer with very high interval
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), totalMaxWeight: 1_000, flushInterval: 0.000001, flushTolerance: 0.0)

        SentryLog.withOutLogs {
            let expectation = expectation(description: "Adding metrics")
            expectation.expectedFulfillmentCount = 100
            
            // Keep adding metrics async so the flush timer has a few chances to
            // send metrics
            for i in 0..<100 {
                DispatchQueue.global().async {
                    sut.increment(key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
                    currentDate.setDate(date: currentDate.date().addingTimeInterval(10.0))
                    
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
            
            XCTAssertGreaterThan(metricsClient.captureInvocations.count, 0, "Repeating flush timer should send some metrics.")
        }
    }

    func testClose_InvalidatesTimer() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        // Start the flush timer with very high interval
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), totalMaxWeight: 1_000, flushInterval: 0.000001, flushTolerance: 0.0)

        sut.close()

        let expectation = expectation(description: "Adding metrics")
        expectation.expectedFulfillmentCount = 100

        // Keep adding metrics async so the flush timer has a few chances to
        // send metrics
        for i in 0..<100 {
            DispatchQueue.global().async {
                sut.increment(key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
                currentDate.setDate(date: currentDate.date().addingTimeInterval(10.0))

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(metricsClient.captureInvocations.count, 0, "No metrics should be sent cause the flush timer should be cancelled.")
    }

    func testFlushCalledOnCallingThread() throws {
        let (sut, _, metricsClient) = try getSut(dispatchQueue: SentryDispatchQueueWrapper())

        let expectation = expectation(description: "Before capture block called")
        metricsClient.afterRecordingCaptureInvocationBlock = {
            XCTAssertEqual(Thread.isMainThread, true, "Flush must be called on the calling thread, but was called on a background thread.")
            expectation.fulfill()
        }

        sut.increment(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.increment(key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
    }

    func testCloseCallsFlush() throws {
        let (sut, _, metricsClient) = try getSut()

        sut.increment(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.increment(key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.close()

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
    }
    
    func testWriteMultipleMetricsInParallel_NonForceFlush_DoesNotCrash() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        // Start the flush timer with very high interval
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), totalMaxWeight: 1_000, flushInterval: 0.001, flushTolerance: 0.0)
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { i in
            sut.increment(key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            currentDate.setDate(date: currentDate.date().addingTimeInterval(0.01))
        })
        
        sut.close()
    }
    
    func testWriteMultipleMetricsInParallel_ForceFlush_DoesNotCrash() throws {
        let (sut, _, _) = try getSut(totalMaxWeight: 5)
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { i in
            sut.increment(key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.gauge(key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.distribution(key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.set(key: "key\(i)", value: 11, unit: .none, tags: ["some": "tag"])
        })
    }
    
    func testCounterMetricGetsForwardedToLocalAggregator() throws {
        let localMetricsAggregator = LocalMetricsAggregator()
        let (sut, _, _) = try getSut()

        sut.increment(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["some": "tag"], localMetricsAggregator: localMetricsAggregator)
        
        let serialized = localMetricsAggregator.serialize()
        XCTAssertEqual(serialized.count, 1)
        let bucket = try XCTUnwrap(serialized["c:key1@day"])
        
        XCTAssertEqual(bucket.count, 1)
        let metric = try XCTUnwrap(bucket.first)
        
        XCTAssertEqual(metric["tags"] as? [String: String], ["some": "tag"])
        XCTAssertEqual(metric["min"] as? Double, 1.0)
        XCTAssertEqual(metric["max"] as? Double, 1.0)
        XCTAssertEqual(metric["count"] as? Int, 1)
        XCTAssertEqual(metric["sum"] as? Double, 1.0)
    }
    
    func testSetMetricOnlyForwardsAddedWeight() throws {
        let localMetricsAggregator = LocalMetricsAggregator()
        let (sut, _, _) = try getSut()

        sut.set(key: "key1", value: 1, unit: MeasurementUnitDuration.day, tags: ["some": "tag"], localMetricsAggregator: localMetricsAggregator)
        // This one doesn't add new weight
        sut.set(key: "key1", value: 1, unit: MeasurementUnitDuration.day, tags: ["some": "tag"], localMetricsAggregator: localMetricsAggregator)
        
        let serialized = localMetricsAggregator.serialize()
        XCTAssertEqual(serialized.count, 1)
        let bucket = try XCTUnwrap(serialized["s:key1@day"])
        
        XCTAssertEqual(bucket.count, 1)
        let metric = try XCTUnwrap(bucket.first)
        
        XCTAssertEqual(metric["tags"] as? [String: String], ["some": "tag"])
        // When no weight added the value is 0.0
        XCTAssertEqual(metric["min"] as? Double, 0.0)
        XCTAssertEqual(metric["max"] as? Double, 1.0)
        XCTAssertEqual(metric["count"] as? Int, 2)
        XCTAssertEqual(metric["sum"] as? Double, 1.0)
    }
    
    func testBeforeEmitMetricCallback() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), beforeEmitMetric: { key, tags in
            if key == "key" {
                return false
            }
            
            if tags == ["my": "tag"] {
                return false
            }
            
            return true
        }, totalMaxWeight: 1_000)

        // removed
        sut.distribution( key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        
        // kept
        sut.distribution(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        
        // removed
        sut.distribution(key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["my": "tag"])

        sut.flush(force: true)

        XCTAssertEqual(metricsClient.captureInvocations.count, 1)
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        XCTAssertEqual(bucket.count, 1)
        let metric = try XCTUnwrap(bucket.first as? DistributionMetric)

        XCTAssertEqual(metric.key, "key1")
        XCTAssertEqual(metric.tags.isEmpty, true)
    }

}
