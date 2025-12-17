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
    
    func testRawValue_whenMetricType_shouldReturnCorrectString() {
        // -- Arrange & Act & Assert --
        XCTAssertEqual(SentryMetricType.counter.rawValue, "counter")
        XCTAssertEqual(SentryMetricType.gauge.rawValue, "gauge")
        XCTAssertEqual(SentryMetricType.distribution.rawValue, "distribution")
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
    
    // MARK: - Value Setter Type Conversion Tests
    
    func testSetValue_whenCounterWithInteger_shouldKeepIntegerValue() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.counter",
            value: .integer(10),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .integer(42)
        
        // -- Assert --
        if case .integer(let intValue) = metric.value {
            XCTAssertEqual(intValue, 42)
        } else {
            XCTFail("Expected integer value")
        }
    }
    
    func testSetValue_whenCounterWithDouble_shouldConvertToIntegerAndLogWarning() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.counter",
            value: .integer(10),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .double(125.7)
        
        // -- Assert --
        if case .integer(let intValue) = metric.value {
            XCTAssertEqual(intValue, 125)
        } else {
            XCTFail("Expected integer value")
        }
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Attempted to set a double value (125.7) on a counter metric") })
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Converting to integer by flooring: 125") })
    }
    
    func testSetValue_whenCounterWithNegativeDouble_shouldFloorToZero() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.counter",
            value: .integer(10),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .double(-5.5)
        
        // -- Assert --
        if case .integer(let intValue) = metric.value {
            XCTAssertEqual(intValue, 0)
        } else {
            XCTFail("Expected integer value")
        }
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Attempted to set a double value (-5.5) on a counter metric") })
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Converting to integer by flooring: 0") })
    }
    
    func testSetValue_whenCounterWithFractionalDouble_shouldFloorCorrectly() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.counter",
            value: .integer(10),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .double(99.999)
        
        // -- Assert --
        if case .integer(let intValue) = metric.value {
            XCTAssertEqual(intValue, 99)
        } else {
            XCTFail("Expected integer value")
        }
    }
    
    func testSetValue_whenGaugeWithDouble_shouldKeepDoubleValue() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.gauge",
            value: .double(10.0),
            type: .gauge,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .double(42.5)
        
        // -- Assert --
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 42.5, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
    }
    
    func testSetValue_whenGaugeWithInteger_shouldConvertToDoubleAndLogWarning() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.gauge",
            value: .double(10.0),
            type: .gauge,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .integer(42)
        
        // -- Assert --
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 42.0, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Attempted to set an integer value (42) on a gauge metric") })
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Converting to double: 42.0") })
    }
    
    func testSetValue_whenDistributionWithDouble_shouldKeepDoubleValue() {
        // -- Arrange --
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.distribution",
            value: .double(10.0),
            type: .distribution,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .double(125.5)
        
        // -- Assert --
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 125.5, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
    }
    
    func testSetValue_whenDistributionWithInteger_shouldConvertToDoubleAndLogWarning() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .warning)
        
        var metric = SentryMetric(
            timestamp: testTimestamp,
            traceId: testTraceId,
            name: "test.distribution",
            value: .double(10.0),
            type: .distribution,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        metric.value = .integer(100)
        
        // -- Assert --
        if case .double(let doubleValue) = metric.value {
            XCTAssertEqual(doubleValue, 100.0, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Attempted to set an integer value (100) on a distribution metric") })
        XCTAssertTrue(logOutput.loggedMessages.contains { $0.contains("Converting to double: 100.0") })
    }

    // MARK: - Helper Methods

    /// Encodes a Metric to JSON Data
    private func encodeToJSONData(data: SentryMetric) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(data)
    }
}
