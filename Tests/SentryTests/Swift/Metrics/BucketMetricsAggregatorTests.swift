@testable import _SentryPrivate
import Nimble
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

        sut.add(type: .distribution, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        currentDate.setDate(date: currentDate.date().addingTimeInterval(9.99))
        sut.add(type: .distribution, key: "key", value: 1.1, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        expect(bucket.count) == 1
        let counterMetric = try XCTUnwrap(bucket.first as? DistributionMetric)

        expect(counterMetric.key) == "key"
        expect(counterMetric.serialize()).to(contain(["1.0", "1.1"]))
        expect(counterMetric.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric.tags) == [:]
    }

    func testFlushShift_MetricsUsuallyInSameBucket_AreInDifferent() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 100, flushShift: 0.1)

        sut.add(type: .gauge, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 9.99))
        sut.add(type: .gauge, key: "key", value: -1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // Not flushing yet
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 1.0))
        sut.flush(force: false)
        expect(metricsClient.captureInvocations.count) == 0

        // This ends up in a different bucket
        sut.add(type: .gauge, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // Now we pass the flush shift threshold
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 0.01))
        sut.flush(force: false)

        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let previousBucketTimestamp = currentDate.bucketTimestamp - 10
        let bucket = try XCTUnwrap(buckets[previousBucketTimestamp])
        expect(bucket.count) == 1
        let counterMetric = try XCTUnwrap(bucket.first as? GaugeMetric)

        expect(counterMetric.key) == "key"
        expect(counterMetric.serialize()) == ["-1.0", "-1.0", "1.0", "0.0", "2"]
        expect(counterMetric.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric.tags) == [:]
    }

    func testDifferentMetrics_NotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut()

        sut.add(type: .set, key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["some": "tag", "and": "another-one"])
        sut.add(type: .set, key: "key2", value: 2.0, unit: MeasurementUnitDuration.day, tags: ["and": "another-one", "some": "tag"])

        sut.flush(force: true)

        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        expect(bucket.count) == 2

        let metric1 = try XCTUnwrap(bucket.first { $0.key == "key1" } as? SetMetric)
        expect(metric1.key) == "key1"
        expect(metric1.serialize()) == ["1"]
        expect(metric1.unit.unit) == MeasurementUnitDuration.day.unit
        expect(metric1.tags) == ["some": "tag", "and": "another-one"]

        let metric2 = try XCTUnwrap(bucket.first { $0.key == "key2" } as? SetMetric)
        expect(metric2.key) == "key2"
        expect(metric2.serialize()) == ["2"]
        expect(metric2.unit.unit) == MeasurementUnitDuration.day.unit
        expect(metric2.tags) == ["some": "tag", "and": "another-one"]
    }

    func testSameMetricDifferentTag_NotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut()

        sut.add(type: .counter, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["some": "tag"])
        sut.add(type: .counter, key: "key", value: 2.0, unit: MeasurementUnitDuration.day, tags: ["some": "other-tag"])

        sut.flush(force: true)

        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        let bucket = try XCTUnwrap(buckets[currentDate.bucketTimestamp])
        expect(bucket.count) == 2

        let counterMetric1 = try XCTUnwrap(bucket.first { $0.tags == ["some": "tag"] } as? CounterMetric)
        expect(counterMetric1.key) == "key"
        expect(counterMetric1.serialize()) == ["1.0"]
        expect(counterMetric1.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric1.tags) == ["some": "tag"]

        let counterMetric2 = try XCTUnwrap(bucket.first { $0.tags == ["some": "other-tag"] } as? CounterMetric)
        expect(counterMetric2.key) == "key"
        expect(counterMetric2.serialize()) == ["2.0"]
        expect(counterMetric2.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric2.tags) == ["some": "other-tag"]
    }

    func testSameMetricNotAggregated_WhenNotInSameBucket() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 5)

        sut.add(type: .counter, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        currentDate.setDate(date: currentDate.date().addingTimeInterval( 10.0))
        sut.add(type: .counter, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        expect(metricsClient.captureInvocations.count) == 1
        let buckets = try XCTUnwrap(metricsClient.captureInvocations.first)

        expect(buckets.count) == 2

        let bucket1 = try XCTUnwrap(buckets.values.first)
        expect(bucket1.count) == 1
        let counterMetric1 = try XCTUnwrap(bucket1.first as? CounterMetric)

        expect(counterMetric1.key) == "key"
        expect(counterMetric1.serialize()) == ["1.0"]
        expect(counterMetric1.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric1.tags) == [:]

        let bucket2 = try XCTUnwrap(Array(buckets.values).last)
        let counterMetric2 = try XCTUnwrap(bucket2.first as? CounterMetric)

        expect(counterMetric2.key) == "key"
        expect(counterMetric2.serialize()) == ["1.0"]
        expect(counterMetric2.unit.unit) == MeasurementUnitDuration.day.unit
        expect(counterMetric2.tags) == [:]
    }

    func testCallFlushWhenOverweight() throws {
        let (sut, _, metricsClient) = try getSut(totalMaxWeight: 3, dispatchQueue: SentryDispatchQueueWrapper())

        let expectation = expectation(description: "Before capture block called")
        metricsClient.afterRecordingCaptureInvocationBlock = {
            expect(Thread.isMainThread).to(equal(false), description: "Flush must be called on a background thread, but was called on the main thread.")
            expectation.fulfill()
        }

        sut.add(type: .counter, key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.add(type: .counter, key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        wait(for: [expectation], timeout: 1.0)
        expect(metricsClient.captureInvocations.count) == 1
    }
    
    func testConvenienceInit_SetsCorrectMaxWeight() throws {
        let metricsClient = try TestMetricsClient()
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: TestCurrentDateProvider(), dispatchQueue: TestSentryDispatchQueueWrapper(), random: SentryRandom())

        for i in 0..<998 {
            sut.add(type: .counter, key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        }
        
        // Total weight is now 999 because the bucket counts for one
        // So nothing should be sent
        expect(metricsClient.captureInvocations.count) == 0
        
        // Now we pass the 1000 threshold
        sut.add(type: .counter, key: "another key", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        expect(metricsClient.captureInvocations.count) == 1
    }

    func testFlushOnlyWhenNeeded() throws {
        let (sut, currentDate, metricsClient) = try getSut(totalMaxWeight: 5)

        sut.add(type: .counter, key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: false)
        expect(metricsClient.captureInvocations.invocations.count) == 0

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 9.99))
        sut.flush(force: false)
        expect(metricsClient.captureInvocations.invocations.count) == 0

        currentDate.setDate(date: currentDate.date().addingTimeInterval( 0.01))
        sut.add(type: .counter, key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: false)
        let buckets1 = try XCTUnwrap(metricsClient.captureInvocations.first)
        expect(buckets1.count) == 1
        expect(buckets1.values.count) == 1

        // Key2 wasn't flushed. We increment it to 2.0
        sut.add(type: .counter, key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        // The weight should be 2 now, so we need to add 3 more to trigger a flush
        sut.add(type: .counter, key: "key3", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.add(type: .counter, key: "key4", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.add(type: .counter, key: "key5", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        expect(metricsClient.captureInvocations.count) == 2
        let buckets2 = try XCTUnwrap(metricsClient.captureInvocations.invocations[1])

        expect(buckets2.count) == 1
        let bucket = try XCTUnwrap(buckets2.first)

        // All 4 metrics should be in the bucket
        expect(bucket.value.count) == 4

        // Check that key2 was incremented
        let counterMetric = try XCTUnwrap(bucket.value.first { $0.key == "key2" } as? CounterMetric)
        expect(counterMetric.serialize()) == ["2.0"]
    }

    func testInitStartsRepeatingTimer() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        // Start the flush timer with very high interval
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), totalMaxWeight: 1_000, flushInterval: 0.000001, flushTolerance: 0.0)

        let expectation = expectation(description: "Adding metrics")
        expectation.expectedFulfillmentCount = 100

        // Keep adding metrics async so the flush timer has a few chances to
        // send metrics
        for i in 0..<100 {
            DispatchQueue.global().async {
                sut.add(type: .counter, key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
                currentDate.setDate(date: currentDate.date().addingTimeInterval(10.0))

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        expect(metricsClient.captureInvocations.count).to(beGreaterThan(0), description: "Repeating flush timer should send some metrics.")
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
                sut.add(type: .counter, key: "key\(i)", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
                currentDate.setDate(date: currentDate.date().addingTimeInterval(10.0))

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        expect(metricsClient.captureInvocations.count).to(equal(0), description: "No metrics should be sent cause the flush timer should be cancelled.")
    }

    func testFlushCalledOnCallingThread() throws {
        let (sut, _, metricsClient) = try getSut(dispatchQueue: SentryDispatchQueueWrapper())

        let expectation = expectation(description: "Before capture block called")
        metricsClient.afterRecordingCaptureInvocationBlock = {
            expect(Thread.isMainThread).to(equal(true), description: "Flush must be called on the calling thread, but was called on a background thread.")
            expectation.fulfill()
        }

        sut.add(type: .counter, key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.add(type: .counter, key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.flush(force: true)

        wait(for: [expectation], timeout: 1.0)
        expect(metricsClient.captureInvocations.count) == 1
    }

    func testCloseCallsFlush() throws {
        let (sut, _, metricsClient) = try getSut()

        sut.add(type: .counter, key: "key1", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])
        sut.add(type: .counter, key: "key2", value: 1.0, unit: MeasurementUnitDuration.day, tags: [:])

        sut.close()

        expect(metricsClient.captureInvocations.count) == 1
    }
    
    func testWriteMultipleMetricsInParallel_NonForceFlush_DoesNotCrash() throws {
        let currentDate = TestCurrentDateProvider()
        let metricsClient = try TestMetricsClient()

        // Start the flush timer with very high interval
        let sut = BucketMetricsAggregator(client: metricsClient, currentDate: currentDate, dispatchQueue: SentryDispatchQueueWrapper(), random: SentryRandom(), totalMaxWeight: 1_000, flushInterval: 0.001, flushTolerance: 0.0)
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { i in
            sut.add(type: .counter, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            currentDate.setDate(date: currentDate.date().addingTimeInterval(0.01))
        })
        
        sut.close()
    }
    
    func testWriteMultipleMetricsInParallel_ForceFlush_DoesNotCrash() throws {
        let (sut, _, _) = try getSut(totalMaxWeight: 5)
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { i in
            sut.add(type: .counter, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .gauge, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .distribution, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .set, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
        })
    }
}
