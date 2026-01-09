@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricTests: XCTestCase {
    
    private let testTimestamp = Date(timeIntervalSince1970: 1_234_567_890.987654)
    private let testTraceId = SentryId(uuidString: "550e8400e29b41d4a716446655440000")
    private let testSpanId = SpanId(value: "b0e6f15b45c36b12")

    // MARK: - Initializer Tests
    
    func testInit_shouldInitializeCorrectly() {
        // -- Act --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.requests",
            value: .counter(1),
            unit: "unit",
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.timestamp, testTimestamp)
        XCTAssertEqual(metric.traceId, testTraceId)
        XCTAssertEqual(metric.name, "api.requests")
        XCTAssertEqual(metric.value, .counter(1))
        XCTAssertEqual(metric.unit, "unit")
        XCTAssertEqual(metric.attributes.count, 0)
    }

    // MARK: - Encoding Tests
    
    func testEncode_whenCounterMetric_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "api.requests",
            value: .counter(1),
            unit: nil,
            attributes: [
                "endpoint": .string("/api/users"),
                "method": .string("GET"),
                "status_code": .integer(200)
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
            value: .distribution(125.5),
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
            value: .gauge(42.0),
            unit: "connection",
            attributes: [
                "pool_name": .string("main_db"),
                "max_size": .integer(100)
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

    // MARK: - Helper Methods

    /// Encodes a Metric to JSON Data
    private func encodeToJSONData(data: SentryMetric) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(data)
    }
}
