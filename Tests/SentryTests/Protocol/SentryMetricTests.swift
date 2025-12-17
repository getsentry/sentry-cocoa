@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricTests: XCTestCase {
    
    private let testTimestamp = Date(timeIntervalSince1970: 1_234_567_890.987654)
    private let testTraceId = SentryId(uuidString: "550e8400e29b41d4a716446655440000")
    private let testSpanId = SpanId(value: "b0e6f15b45c36b12")

    // MARK: - Counter Metric Tests
    
    func testInit_whenCounterMetric_shouldInitializeCorrectly() {
        // -- Act --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.requests",
            value: .integer(1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.timestamp, testTimestamp)
        XCTAssertEqual(metric.traceId, testTraceId)
        XCTAssertEqual(metric.name, "api.requests")
        if case .integer(let intValue) = metric.value {
            XCTAssertEqual(intValue, 1)
        } else {
            XCTFail("Expected integer value")
        }
        XCTAssertEqual(metric.metricType, .counter)
        XCTAssertNil(metric.unit)
        XCTAssertEqual(metric.attributes.count, 0)
    }
    
    func testInit_whenCounterMetricWithAttributes_shouldInitializeWithAttributes() {
        // -- Arrange --
        let attributes: [String: SentryAttribute] = [
            "endpoint": .init(string: "/api/users"),
            "method": .init(string: "GET"),
            "status_code": .init(integer: 200)
        ]
        
        // -- Act --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.requests",
            value: .integer(1),
            type: .counter,
            unit: nil,
            attributes: attributes
        )
        
        // -- Assert --
        XCTAssertEqual(metric.attributes.count, 3)
        XCTAssertEqual(metric.attributes["endpoint"]?.value as? String, "/api/users")
        XCTAssertEqual(metric.attributes["method"]?.value as? String, "GET")
        XCTAssertEqual(metric.attributes["status_code"]?.value as? Int, 200)
    }
    
    // MARK: - Distribution Metric Tests
    
    func testInit_whenDistributionMetric_shouldInitializeCorrectly() {
        // -- Arrange --
        
        // -- Act --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.response_time",
            value: .double(125.5),
            type: .distribution,
            unit: "millisecond",
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.name, "api.response_time")
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 125.5, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
        XCTAssertEqual(metric.metricType, .distribution)
        XCTAssertEqual(metric.unit, "millisecond")
    }
    
    // MARK: - Gauge Metric Tests
    
    func testInit_whenGaugeMetric_shouldInitializeCorrectly() {
        // -- Arrange --
        
        // -- Act --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "db.connection_pool.active",
            value: .double(42.0),
            type: .gauge,
            unit: "connection",
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.name, "db.connection_pool.active")
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 42.0, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
        XCTAssertEqual(metric.metricType, .gauge)
        XCTAssertEqual(metric.unit, "connection")
    }
    
    // MARK: - Attribute Tests
    
    func testSetAttribute_whenAttributeSet_shouldAddAttribute() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.metric",
            value: .integer(1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.setAttribute(.init(string: "test_value"), forKey: "test_key")
        
        // -- Assert --
        XCTAssertEqual(metric.attributes["test_key"]?.value as? String, "test_value")
    }
    
    func testSetAttribute_whenAttributeSetToNil_shouldRemoveAttribute() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.metric",
            value: .integer(1),
            type: .counter,
            unit: nil,
            attributes: ["test_key": .init(string: "test_value")]
        )
        
        // -- Act --
        metric.setAttribute(nil, forKey: "test_key")
        
        // -- Assert --
        XCTAssertNil(metric.attributes["test_key"])
    }
    
    // MARK: - Encoding Tests
    
    func testEncode_whenCounterMetric_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.requests",
            value: .integer(1),
            type: .counter,
            unit: nil,
            attributes: [
                "endpoint": .init(string: "/api/users"),
                "method": .init(string: "GET"),
                "status_code": .init(integer: 200)
            ]
        )
        
        // -- Act --
        let data = try encodeToJSONData(data: metric)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["timestamp"] as? TimeInterval, 1_234_567_890.987654)
        XCTAssertEqual(json["trace_id"] as? String, "550e8400e29b41d4a716446655440000")
        XCTAssertNil(json["span_id"])
        XCTAssertEqual(json["name"] as? String, "api.requests")
        XCTAssertEqual(json["value"] as? Int, 1)
        XCTAssertEqual(json["type"] as? String, "counter")
        XCTAssertNil(json["unit"])
        
        let encodedAttributes = try XCTUnwrap(json["attributes"] as? [String: [String: Any]])
        XCTAssertEqual(encodedAttributes["endpoint"]?["type"] as? String, "string")
        XCTAssertEqual(encodedAttributes["endpoint"]?["value"] as? String, "/api/users")
        XCTAssertEqual(encodedAttributes["status_code"]?["type"] as? String, "integer")
        XCTAssertEqual(encodedAttributes["status_code"]?["value"] as? Int, 200)
    }
    
    func testEncode_whenDistributionMetric_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.response_time",
            value: .double(125.5),
            type: .distribution,
            unit: "millisecond",
            attributes: [:]
        )
        
        // -- Act --
        let data = try encodeToJSONData(data: metric)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["name"] as? String, "api.response_time")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, 125.5, accuracy: 0.001)
        XCTAssertEqual(json["type"] as? String, "distribution")
        XCTAssertEqual(json["unit"] as? String, "millisecond")
        XCTAssertNil(json["span_id"])
    }
    
    func testEncode_whenGaugeMetric_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "db.connection_pool.active",
            value: .double(42.0),
            type: .gauge,
            unit: "connection",
            attributes: [
                "pool_name": .init(string: "main_db"),
                "max_size": .init(integer: 100)
            ]
        )
        
        // -- Act --
        let data = try encodeToJSONData(data: metric)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["name"] as? String, "db.connection_pool.active")
        let value = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(value, 42.0, accuracy: 0.001)
        XCTAssertEqual(json["type"] as? String, "gauge")
        XCTAssertEqual(json["unit"] as? String, "connection")
    }
    
    // MARK: - SentryMetricType Tests
    
    func testStringValue_whenMetricType_shouldReturnCorrectString() {
        // -- Arrange & Act & Assert --
        XCTAssertEqual(SentryMetricType.counter.stringValue, "counter")
        XCTAssertEqual(SentryMetricType.gauge.stringValue, "gauge")
        XCTAssertEqual(SentryMetricType.distribution.stringValue, "distribution")
    }
    
    func testEncode_whenMetricType_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let encoder = JSONEncoder()
        
        // -- Act & Assert --
        let counterData = try encoder.encode(SentryMetricType.counter)
        let counterString = String(data: counterData, encoding: .utf8)
        XCTAssertEqual(counterString, "\"counter\"")
        
        let gaugeData = try encoder.encode(SentryMetricType.gauge)
        let gaugeString = String(data: gaugeData, encoding: .utf8)
        XCTAssertEqual(gaugeString, "\"gauge\"")
        
        let distributionData = try encoder.encode(SentryMetricType.distribution)
        let distributionString = String(data: distributionData, encoding: .utf8)
        XCTAssertEqual(distributionString, "\"distribution\"")
    }

    // MARK: - Helper Methods

    /// Encodes a Metric to JSON Data
    private func encodeToJSONData(data: SentryMetric) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(data)
    }
}
