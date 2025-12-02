@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricTests: XCTestCase {
    
    private var metric: SentryMetric!
    private let testTimestamp = Date(timeIntervalSince1970: 1_234_567_890.987654)
    private let testTraceId = SentryId(uuidString: "550e8400e29b41d4a716446655440000")
    private let testSpanId = SentrySpanId(value: "b0e6f15b45c36b12")
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        metric = nil
    }
    
    // MARK: - Counter Metric Tests
    
    func testCounterMetric_Initialization() {
        // -- Arrange & Act --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "api.requests",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.timestamp, testTimestamp)
        XCTAssertEqual(metric.traceId, testTraceId)
        XCTAssertNil(metric.spanId)
        XCTAssertEqual(metric.name, "api.requests")
        XCTAssertEqual(metric.value.intValue, 1)
        XCTAssertEqual(metric.type, .counter)
        XCTAssertNil(metric.unit)
        XCTAssertEqual(metric.attributes.count, 0)
    }
    
    func testCounterMetric_WithAttributes() {
        // -- Arrange & Act --
        let attributes: [String: SentryMetric.Attribute] = [
            "endpoint": .init(string: "/api/users"),
            "method": .init(string: "GET"),
            "status_code": .init(integer: 200)
        ]
        
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: testSpanId,
            name: "api.requests",
            value: NSNumber(value: 1),
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
    
    func testDistributionMetric_Initialization() {
        // -- Arrange & Act --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "api.response_time",
            value: NSNumber(value: 125.5),
            type: .distribution,
            unit: "millisecond",
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.name, "api.response_time")
        XCTAssertEqual(metric.value.doubleValue, 125.5, accuracy: 0.001)
        XCTAssertEqual(metric.type, .distribution)
        XCTAssertEqual(metric.unit, "millisecond")
    }
    
    // MARK: - Gauge Metric Tests
    
    func testGaugeMetric_Initialization() {
        // -- Arrange & Act --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "db.connection_pool.active",
            value: NSNumber(value: 42.0),
            type: .gauge,
            unit: "connection",
            attributes: [:]
        )
        
        // -- Assert --
        XCTAssertEqual(metric.name, "db.connection_pool.active")
        XCTAssertEqual(metric.value.doubleValue, 42.0, accuracy: 0.001)
        XCTAssertEqual(metric.type, .gauge)
        XCTAssertEqual(metric.unit, "connection")
    }
    
    // MARK: - Attribute Tests
    
    func testSetAttribute() {
        // -- Arrange --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "test.metric",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.setAttribute(.init(string: "test_value"), forKey: "test_key")
        
        // -- Assert --
        XCTAssertEqual(metric.attributes["test_key"]?.value as? String, "test_value")
    }
    
    func testRemoveAttribute() {
        // -- Arrange --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "test.metric",
            value: NSNumber(value: 1),
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
    
    func testEncode_Counter() throws {
        // -- Arrange --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: testSpanId,
            name: "api.requests",
            value: NSNumber(value: 1),
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
        XCTAssertEqual(json["span_id"] as? String, "b0e6f15b45c36b12")
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
    
    func testEncode_Distribution() throws {
        // -- Arrange --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "api.response_time",
            value: NSNumber(value: 125.5),
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
    
    func testEncode_Gauge() throws {
        // -- Arrange --
        metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            spanId: nil,
            name: "db.connection_pool.active",
            value: NSNumber(value: 42.0),
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
    
    // MARK: - Decoding Tests
    
    func testDecode_Counter() throws {
        // -- Arrange --
        let jsonData = Data("""
        {
            "timestamp": 1234567890.987654,
            "trace_id": "550e8400e29b41d4a716446655440000",
            "span_id": "b0e6f15b45c36b12",
            "name": "api.requests",
            "value": 1,
            "type": "counter",
            "attributes": {
                "endpoint": {"type": "string", "value": "/api/users"},
                "status_code": {"type": "integer", "value": 200}
            }
        }
        """.utf8)
        
        // -- Act --
        let decodedMetric = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryMetric?)
        
        // -- Assert --
        XCTAssertEqual(decodedMetric.timestamp, Date(timeIntervalSince1970: 1_234_567_890.987654))
        XCTAssertEqual(decodedMetric.traceId.sentryIdString, "550e8400e29b41d4a716446655440000")
        XCTAssertEqual(decodedMetric.spanId?.sentrySpanIdString, "b0e6f15b45c36b12")
        XCTAssertEqual(decodedMetric.name, "api.requests")
        XCTAssertEqual(decodedMetric.value.intValue, 1)
        XCTAssertEqual(decodedMetric.type, .counter)
        XCTAssertEqual(decodedMetric.attributes["endpoint"]?.value as? String, "/api/users")
        XCTAssertEqual(decodedMetric.attributes["status_code"]?.value as? Int, 200)
    }
    
    func testDecode_Distribution() throws {
        // -- Arrange --
        let jsonData = Data("""
        {
            "timestamp": 1234567890.987654,
            "trace_id": "550e8400e29b41d4a716446655440000",
            "name": "api.response_time",
            "value": 125.5,
            "type": "distribution",
            "unit": "millisecond"
        }
        """.utf8)
        
        // -- Act --
        let decodedMetric = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryMetric?)
        
        // -- Assert --
        XCTAssertEqual(decodedMetric.name, "api.response_time")
        XCTAssertEqual(decodedMetric.value.doubleValue, 125.5, accuracy: 0.001)
        XCTAssertEqual(decodedMetric.type, .distribution)
        XCTAssertEqual(decodedMetric.unit, "millisecond")
        XCTAssertNil(decodedMetric.spanId)
    }
    
    func testDecode_Gauge() throws {
        // -- Arrange --
        let jsonData = Data("""
        {
            "timestamp": 1234567890.987654,
            "trace_id": "550e8400e29b41d4a716446655440000",
            "name": "db.connection_pool.active",
            "value": 42.0,
            "type": "gauge",
            "unit": "connection"
        }
        """)
        
        // -- Act --
        let decodedMetric = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryMetric?)
        
        // -- Assert --
        XCTAssertEqual(decodedMetric.name, "db.connection_pool.active")
        XCTAssertEqual(decodedMetric.value.doubleValue, 42.0, accuracy: 0.001)
        XCTAssertEqual(decodedMetric.type, .gauge)
        XCTAssertEqual(decodedMetric.unit, "connection")
    }
    
    // MARK: - MetricType Tests
    
    func testMetricType_StringValues() {
        XCTAssertEqual(MetricType.counter.stringValue, "counter")
        XCTAssertEqual(MetricType.gauge.stringValue, "gauge")
        XCTAssertEqual(MetricType.distribution.stringValue, "distribution")
    }
    
    func testMetricType_Encode() throws {
        let encoder = JSONEncoder()
        let counterData = try encoder.encode(MetricType.counter)
        let counterString = String(data: counterData, encoding: .utf8)
        XCTAssertEqual(counterString, "\"counter\"")
        
        let gaugeData = try encoder.encode(MetricType.gauge)
        let gaugeString = String(data: gaugeData, encoding: .utf8)
        XCTAssertEqual(gaugeString, "\"gauge\"")
        
        let distributionData = try encoder.encode(MetricType.distribution)
        let distributionString = String(data: distributionData, encoding: .utf8)
        XCTAssertEqual(distributionString, "\"distribution\"")
    }
    
    func testMetricType_Decode() throws {
        let decoder = JSONDecoder()
        
        let counterData = Data("\"counter\"".utf8)
        let counter = try decoder.decode(MetricType.self, from: counterData)
        XCTAssertEqual(counter, .counter)
        
        let gaugeData = Data("\"gauge\"".utf8)
        let gauge = try decoder.decode(MetricType.self, from: gaugeData)
        XCTAssertEqual(gauge, .gauge)
        
        let distributionData = Data("\"distribution\"".utf8)
        let distribution = try decoder.decode(MetricType.self, from: distributionData)
        XCTAssertEqual(distribution, .distribution)
    }
}
