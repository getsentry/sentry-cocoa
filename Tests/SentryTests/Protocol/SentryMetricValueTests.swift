@_spi(Private) @testable import Sentry
import XCTest

final class SentryMetricValueTests: XCTestCase {

    // MARK: - Encoding Tests
    
    func testEncode_whenCounter_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.counter(42)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "counter")
        XCTAssertEqual(json["value"] as? Int64, 42)
    }
    
    func testEncode_whenCounterWithLargeValue_shouldEncodeAsInt64() throws {
        // -- Arrange --
        // Use a value larger than Int64.max (9,223,372,036,854,775,807) but within UInt64 range
        // to verify truncation behavior
        let largeValue: UInt = 10_000_000_000_000_000_000 // 10 quintillion
        let metricValue = SentryMetricValue.counter(largeValue)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "counter")
        // Verify truncation: Int64(truncatingIfNeeded:) wraps around when value exceeds Int64.max
        XCTAssertEqual(json["value"] as? Int64, Int64(truncatingIfNeeded: largeValue))
    }
    
    func testEncode_whenDistribution_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.distribution(125.5)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "distribution")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, 125.5, accuracy: 0.001)
    }
    
    func testEncode_whenGauge_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.gauge(42.0)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "gauge")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, 42.0, accuracy: 0.001)
    }

    // MARK: - Equality Tests
    
    func testEquality_whenSameCounterValues_shouldBeEqual() {
        // -- Arrange --
        let value1 = SentryMetricValue.counter(42)
        let value2 = SentryMetricValue.counter(42)
        
        // -- Act & Assert --
        XCTAssertEqual(value1, value2)
    }
    
    func testEquality_whenDifferentCounterValues_shouldNotBeEqual() {
        // -- Arrange --
        let value1 = SentryMetricValue.counter(42)
        let value2 = SentryMetricValue.counter(43)
        
        // -- Act & Assert --
        XCTAssertNotEqual(value1, value2)
    }
    
    func testEquality_whenSameGaugeValues_shouldBeEqual() {
        // -- Arrange --
        let value1 = SentryMetricValue.gauge(42.0)
        let value2 = SentryMetricValue.gauge(42.0)
        
        // -- Act & Assert --
        XCTAssertEqual(value1, value2)
    }
    
    func testEquality_whenDifferentGaugeValues_shouldNotBeEqual() {
        // -- Arrange --
        let value1 = SentryMetricValue.gauge(42.0)
        let value2 = SentryMetricValue.gauge(43.0)
        
        // -- Act & Assert --
        XCTAssertNotEqual(value1, value2)
    }
    
    func testEquality_whenSameDistributionValues_shouldBeEqual() {
        // -- Arrange --
        let value1 = SentryMetricValue.distribution(125.5)
        let value2 = SentryMetricValue.distribution(125.5)
        
        // -- Act & Assert --
        XCTAssertEqual(value1, value2)
    }
    
    func testEquality_whenDifferentTypes_shouldNotBeEqual() {
        // -- Arrange --
        let counter = SentryMetricValue.counter(42)
        let gauge = SentryMetricValue.gauge(42.0)
        let distribution = SentryMetricValue.distribution(42.0)
        
        // -- Act & Assert --
        XCTAssertNotEqual(counter, gauge)
        XCTAssertNotEqual(counter, distribution)
        XCTAssertNotEqual(gauge, distribution)
    }

    // MARK: - Hashable Tests
    
    func testHash_whenSameValues_shouldBeTreatedAsEqualInSet() {
        // -- Arrange --
        let value1 = SentryMetricValue.counter(42)
        let value2 = SentryMetricValue.counter(42)
        
        // -- Act --
        var set = Set<SentryMetricValue>()
        set.insert(value1)
        set.insert(value2)
        
        // -- Assert --
        XCTAssertEqual(set.count, 1, "Equal values should be treated as the same in a Set")
    }
    
    func testHash_whenDifferentValues_shouldBeTreatedAsDifferentInSet() {
        // -- Arrange --
        let value1 = SentryMetricValue.counter(42)
        let value2 = SentryMetricValue.counter(43)
        
        // -- Act --
        var set = Set<SentryMetricValue>()
        set.insert(value1)
        set.insert(value2)
        
        // -- Assert --
        XCTAssertEqual(set.count, 2, "Different values should be treated as different in a Set")
    }
    
    func testHash_whenDifferentTypes_shouldBeTreatedAsDifferentInSet() {
        // -- Arrange --
        let counter = SentryMetricValue.counter(42)
        let gauge = SentryMetricValue.gauge(42.0)
        let distribution = SentryMetricValue.distribution(42.0)
        
        // -- Act --
        var set = Set<SentryMetricValue>()
        set.insert(counter)
        set.insert(gauge)
        set.insert(distribution)
        
        // -- Assert --
        XCTAssertEqual(set.count, 3, "Different types should be treated as different in a Set")
    }
    
    // MARK: - Edge Case Tests
    
    func testEncode_whenCounterZero_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.counter(0)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "counter")
        XCTAssertEqual(json["value"] as? Int64, 0)
    }
    
    func testEncode_whenGaugeZero_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.gauge(0.0)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "gauge")
        XCTAssertEqual(json["value"] as? Double, 0.0)
    }
    
    func testEncode_whenDistributionZero_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.distribution(0.0)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "distribution")
        XCTAssertEqual(json["value"] as? Double, 0.0)
    }
    
    func testEncode_whenGaugeNegative_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.gauge(-42.5)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "gauge")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, -42.5, accuracy: 0.001)
    }
    
    func testEncode_whenDistributionNegative_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metricValue = SentryMetricValue.distribution(-125.5)
        
        // -- Act --
        let data = try JSONEncoder().encode(metricValue)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "distribution")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, -125.5, accuracy: 0.001)
    }
    
    func testEncode_whenGaugeInfinity_shouldThrowError() {
        // -- Arrange --
        let metricValue = SentryMetricValue.gauge(Double.infinity)
        
        // -- Act & Assert --
        XCTAssertThrowsError(try JSONEncoder().encode(metricValue)) { error in
            // JSONEncoder cannot encode Double.infinity, so encoding should fail
            XCTAssertTrue(error is EncodingError, "Encoding should throw an EncodingError for infinity")
        }
    }
    
    func testEncode_whenDistributionNaN_shouldThrowError() {
        // -- Arrange --
        let metricValue = SentryMetricValue.distribution(Double.nan)
        
        // -- Act & Assert --
        XCTAssertThrowsError(try JSONEncoder().encode(metricValue)) { error in
            // JSONEncoder cannot encode Double.nan, so encoding should fail
            XCTAssertTrue(error is EncodingError, "Encoding should throw an EncodingError for NaN")
        }
    }
}
