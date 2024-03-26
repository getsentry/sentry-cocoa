import Nimble
@testable import Sentry
import XCTest

final class LocalMetricsAggregatorTests: XCTestCase {

    func testAddOneCounterMetric() throws {
        let sut = LocalMetricsAggregator()
        
        sut.add(type: .counter, key: "key", value: 1.0, unit: MeasurementUnitDuration.second, tags: [:])
        
        let serialized = sut.serialize()
        expect(serialized.count) == 1
        let bucket = try XCTUnwrap(serialized["c:key@second"])
        
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        
        expect(metric["tags"]) == nil
        expect(metric["min"] as? Double) == 1.0
        expect(metric["max"] as? Double) == 1.0
        expect(metric["count"] as? Int) == 1
        expect(metric["sum"] as? Double) == 1.0
    }

    func testAddTwoSameDistributionMetrics() throws {
        let sut = LocalMetricsAggregator()
        
        sut.add(type: .distribution, key: "key", value: 1.0, unit: MeasurementUnitDuration.second, tags: [:])
        sut.add(type: .distribution, key: "key", value: 1.1, unit: MeasurementUnitDuration.second, tags: [:])
        
        let serialized = sut.serialize()
        expect(serialized.count) == 1
        let bucket = try XCTUnwrap(serialized["d:key@second"])
        
        expect(bucket.count) == 1
        let metric = try XCTUnwrap(bucket.first)
        
        expect(metric["tags"]) == nil
        expect(metric["min"] as? Double) == 1.0
        expect(metric["max"] as? Double) == 1.1
        expect(metric["count"] as? Int) == 2
        expect(metric["sum"] as? Double) == 2.1
    }
    
    func testAddTwoGaugeMetrics_WithDifferentTags() throws {
        let sut = LocalMetricsAggregator()
        
        sut.add(type: .gauge, key: "key", value: 1.0, unit: MeasurementUnitDuration.second, tags: ["some0": "tag0"])
        sut.add(type: .gauge, key: "key", value: 10.0, unit: MeasurementUnitDuration.second, tags: ["some1": "tag1"])
        
        let serialized = sut.serialize()
        expect(serialized.count) == 1
        let bucket = try XCTUnwrap(serialized["g:key@second"])
        
        expect(bucket.count) == 2
        let metric0 = try XCTUnwrap(bucket.first { $0.contains { $0.value as? [String: String] == ["some0": "tag0"] } })
        
        expect(metric0["min"] as? Double) == 1.0
        expect(metric0["max"] as? Double) == 1.0
        expect(metric0["count"] as? Int) == 1
        expect(metric0["sum"] as? Double) == 1.0
        
        let metric1 = try XCTUnwrap(bucket.first { $0.contains { $0.value as? [String: String] == ["some1": "tag1"] } })
        
        expect(metric1["min"] as? Double) == 10.0
        expect(metric1["max"] as? Double) == 10.0
        expect(metric1["count"] as? Int) == 1
        expect(metric1["sum"] as? Double) == 10.0
    }
    
    func testAddTwoDifferentMetrics() throws {
        let sut = LocalMetricsAggregator()
        
        sut.add(type: .gauge, key: "key", value: 1.0, unit: MeasurementUnitDuration.day, tags: ["some0": "tag0"])
        sut.add(type: .gauge, key: "key", value: 10.0, unit: MeasurementUnitDuration.second, tags: ["some1": "tag1"])
        sut.add(type: .gauge, key: "key", value: -10.0, unit: MeasurementUnitDuration.second, tags: ["some1": "tag1"])
        
        let serialized = sut.serialize()
        expect(serialized.count) == 2
        let dayBucket = try XCTUnwrap(serialized["g:key@day"])
        
        expect(dayBucket.count) == 1
        let dayMetric = try XCTUnwrap(dayBucket.first)
        expect(dayMetric["min"] as? Double) == 1.0
        expect(dayMetric["max"] as? Double) == 1.0
        expect(dayMetric["count"] as? Int) == 1
        expect(dayMetric["sum"] as? Double) == 1.0
        
        let secondBucket = try XCTUnwrap(serialized["g:key@second"])
        expect(secondBucket.count) == 1
        let secondMetric = try XCTUnwrap(secondBucket.first)
        expect(secondMetric["min"] as? Double) == -10.0
        expect(secondMetric["max"] as? Double) == 10.0
        expect(secondMetric["count"] as? Int) == 2
        expect(secondMetric["sum"] as? Double) == 0.0
    }
    
    func testWriteMultipleMetricsInParallel_DoesNotCrash() throws {
        let sut = LocalMetricsAggregator()
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 100, writeWork: { i in
            sut.add(type: .counter, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .gauge, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .distribution, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
            sut.add(type: .set, key: "key\(i)", value: 1.1, unit: .none, tags: ["some": "tag"])
        }, readWork: {
            expect(sut.serialize()) != nil
        })
    }
}
