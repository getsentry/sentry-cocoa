import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// This test suite tests the SentryMetricsApi on a end-to-end level as it uses the public API and asserts the envelopes which would be sent by the client.
class SentryMetricsApiE2ETests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    // MARK: - Tests - Count
    
    func testCount_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.count(key: "network.request.count", value: 1)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created when SDK is enabled")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "network.request.count", "Metric key should match")
        XCTAssertEqual(metric["value"] as? Int64, 1, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "counter", "Metric type should be counter")
    }
    
    func testCount_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        // Disable SDK by removing client from hub
        let hub = SentrySDKInternal.currentHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: hub.scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        XCTAssertFalse(SentrySDK.isEnabled, "SDK should be disabled")
        
        // -- Act --
        SentrySDK.metrics.count(key: "test.metric", value: 1)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be captured when SDK is disabled")
    }
    
    func testCount_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub(isMetricsEnabled: false)
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.count(key: "test.metric", value: 1)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be created when metrics are disabled")
    }
    
    func testCount_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.count(key: "button.click", value: 0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for zero values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "button.click", "Metric key should match")
        XCTAssertEqual(metric["value"] as? Int64, 0, "Metric value should be zero")
        XCTAssertEqual(metric["type"] as? String, "counter", "Metric type should be counter")
    }
    
    func testCount_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.count(key: "events.processed", value: 1_000_000_000)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created for large values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "events.processed", "Metric key should match")
        XCTAssertEqual(metric["value"] as? Int64, 1_000_000_000, "Metric value should match large value")
        XCTAssertEqual(metric["type"] as? String, "counter", "Metric type should be counter")
    }
    
    func testCount_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.count(
            key: "api.request.count",
            value: 1,
            attributes: [
                "endpoint": "api/users",
                "success": true,
                "status_code": 200,
                "response_time": 0.125
            ]
        )
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created with attributes")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "api.request.count", "Metric key should match")
        XCTAssertEqual(metric["value"] as? Int64, 1, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "counter", "Metric type should be counter")
        
        let attributes = try XCTUnwrap(metric["attributes"] as? [String: Any])
        
        let endpointAttr = try XCTUnwrap(attributes["endpoint"] as? [String: Any], "endpoint attribute should exist")
        XCTAssertEqual(endpointAttr["value"] as? String, "api/users", "endpoint attribute value should match")
        
        let successAttr = try XCTUnwrap(attributes["success"] as? [String: Any], "success attribute should exist")
        XCTAssertEqual(successAttr["value"] as? Bool, true, "success attribute value should match")
        
        let statusCodeAttr = try XCTUnwrap(attributes["status_code"] as? [String: Any], "status_code attribute should exist")
        XCTAssertEqual(statusCodeAttr["value"] as? Int, 200, "status_code attribute value should match")
        
        let responseTimeAttr = try XCTUnwrap(attributes["response_time"] as? [String: Any], "response_time attribute should exist")
        XCTAssertEqual(try XCTUnwrap(responseTimeAttr["value"] as? Double), 0.125, accuracy: 0.001, "response_time attribute value should match")
    }
    
    // MARK: - Tests - Distribution
    
    func testDistribution_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "http.request.duration", value: 187.5)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created when SDK is enabled")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "http.request.duration", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 187.5, accuracy: 0.001, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "distribution", "Metric type should be distribution")
    }
    
    func testDistribution_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        // Disable SDK by removing client from hub
        let hub = SentrySDKInternal.currentHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: hub.scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        XCTAssertFalse(SentrySDK.isEnabled, "SDK should be disabled")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "test.metric", value: 1.0)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be captured when SDK is disabled")
    }
    
    func testDistribution_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub(isMetricsEnabled: false)
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "test.metric", value: 1.0)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be created when metrics are disabled")
    }
    
    func testDistribution_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "response.time", value: 0.0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for zero values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "response.time", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 0.0, accuracy: 0.001, "Metric value should be zero")
        XCTAssertEqual(metric["type"] as? String, "distribution", "Metric type should be distribution")
    }
    
    func testDistribution_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "processing.duration", value: 999_999.99)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created for large values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "processing.duration", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 999_999.99, accuracy: 0.01, "Metric value should match large value")
        XCTAssertEqual(metric["type"] as? String, "distribution", "Metric type should be distribution")
    }
    
    func testDistribution_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(key: "latency", value: -10.5)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for negative values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "latency", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), -10.5, accuracy: 0.001, "Metric value should match negative value")
        XCTAssertEqual(metric["type"] as? String, "distribution", "Metric type should be distribution")
    }
    
    func testDistribution_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.distribution(
            key: "db.query.duration",
            value: 45.7,
            attributes: [
                "database": "postgres",
                "cached": false,
                "query_count": 3,
                "cache_hit_rate": 0.85
            ]
        )
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created with attributes")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "db.query.duration", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 45.7, accuracy: 0.001, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "distribution", "Metric type should be distribution")
        
        let attributes = try XCTUnwrap(metric["attributes"] as? [String: Any])
        
        let databaseAttr = try XCTUnwrap(attributes["database"] as? [String: Any], "database attribute should exist")
        XCTAssertEqual(databaseAttr["value"] as? String, "postgres", "database attribute value should match")
        
        let cachedAttr = try XCTUnwrap(attributes["cached"] as? [String: Any], "cached attribute should exist")
        XCTAssertEqual(cachedAttr["value"] as? Bool, false, "cached attribute value should match")
        
        let queryCountAttr = try XCTUnwrap(attributes["query_count"] as? [String: Any], "query_count attribute should exist")
        XCTAssertEqual(queryCountAttr["value"] as? Int, 3, "query_count attribute value should match")
        
        let cacheHitRateAttr = try XCTUnwrap(attributes["cache_hit_rate"] as? [String: Any], "cache_hit_rate attribute should exist")
        XCTAssertEqual(try XCTUnwrap(cacheHitRateAttr["value"] as? Double), 0.85, accuracy: 0.001, "cache_hit_rate attribute value should match")
    }
    
    // MARK: - Tests - Gauge
    
    func testGauge_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "memory.usage", value: 1_024.0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created when SDK is enabled")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "memory.usage", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 1_024.0, accuracy: 0.001, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "gauge", "Metric type should be gauge")
    }
    
    func testGauge_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        // Disable SDK by removing client from hub
        let hub = SentrySDKInternal.currentHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: hub.scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        XCTAssertFalse(SentrySDK.isEnabled, "SDK should be disabled")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "test.metric", value: 1.0)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be captured when SDK is disabled")
    }
    
    func testGauge_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub(isMetricsEnabled: false)
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "test.metric", value: 1.0)
        try flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 0, "No metrics should be created when metrics are disabled")
    }
    
    func testGauge_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "queue.depth", value: 0.0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for zero values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "queue.depth", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 0.0, accuracy: 0.001, "Metric value should be zero")
        XCTAssertEqual(metric["type"] as? String, "gauge", "Metric type should be gauge")
    }
    
    func testGauge_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "active.connections", value: 50_000.0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created for large values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "active.connections", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 50_000.0, accuracy: 0.001, "Metric value should match large value")
        XCTAssertEqual(metric["type"] as? String, "gauge", "Metric type should be gauge")
    }
    
    func testGauge_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(key: "temperature", value: -5.0)
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for negative values")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "temperature", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), -5.0, accuracy: 0.001, "Metric value should match negative value")
        XCTAssertEqual(metric["type"] as? String, "gauge", "Metric type should be gauge")
        
        // Assert no further invocations
        XCTAssertEqual(1, client.captureMetricsDataInvocations.count, "Uninstall should flush metrics")
    }
    
    func testGauge_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")
        
        // -- Act --
        SentrySDK.metrics.gauge(
            key: "system.cpu.usage",
            value: 75.5,
            attributes: [
                "process": "main_app",
                "compressed": true,
                "core_count": 8,
                "utilization": 0.755
            ]
        )
        try flushMetrics()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metric should be created with attributes")
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        
        let metrics = getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.first)
        XCTAssertEqual(metric["name"] as? String, "system.cpu.usage", "Metric key should match")
        XCTAssertEqual(try XCTUnwrap(metric["value"] as? Double), 75.5, accuracy: 0.001, "Metric value should match")
        XCTAssertEqual(metric["type"] as? String, "gauge", "Metric type should be gauge")
        
        let attributes = try XCTUnwrap(metric["attributes"] as? [String: Any])
        
        let processAttr = try XCTUnwrap(attributes["process"] as? [String: Any], "process attribute should exist")
        XCTAssertEqual(processAttr["value"] as? String, "main_app", "process attribute value should match")
        
        let compressedAttr = try XCTUnwrap(attributes["compressed"] as? [String: Any], "compressed attribute should exist")
        XCTAssertEqual(compressedAttr["value"] as? Bool, true, "compressed attribute value should match")
        
        let coreCountAttr = try XCTUnwrap(attributes["core_count"] as? [String: Any], "core_count attribute should exist")
        XCTAssertEqual(coreCountAttr["value"] as? Int, 8, "core_count attribute value should match")
        
        let utilizationAttr = try XCTUnwrap(attributes["utilization"] as? [String: Any], "utilization attribute should exist")
        XCTAssertEqual(try XCTUnwrap(utilizationAttr["value"] as? Double), 0.755, accuracy: 0.001, "utilization attribute value should match")
    }
    
    // MARK: - Helpers
    
    private func givenSdkWithHub(isSDKEnabled: Bool = true, isMetricsEnabled: Bool = true) throws {
        guard isSDKEnabled else {
            return
        }
        
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.removeAllIntegrations()
        
        options.experimental.enableMetrics = isMetricsEnabled
        
        let client = TestClient(options: options)
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        
        SentrySDK.setStart(with: options)
        SentrySDKInternal.setCurrentHub(hub)
        
        if isMetricsEnabled {
            // Manually install the MetricsIntegration since we're not using SentrySDK.start()
            let dependencies = SentryDependencyContainer.sharedInstance()
            let integration = try XCTUnwrap(
                SentryMetricsIntegration<SentryDependencyContainer>(
                    with: options,
                    dependencies: dependencies
                ) as Any as? SentryIntegrationProtocol
            )
            hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<SentryDependencyContainer>.name)
        }
        
        hub.startSession()
    }
    
    private func getIntegration() throws -> SentryMetricsIntegration<SentryDependencyContainer>? {
        return SentrySDKInternal.currentHub().integrationRegistry.getIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self)
    }
    
    private func flushMetrics() throws {
        // We can not rely on the SentrySDK.flush(), because we are using a test client which is not actually
        // flushing integrations as of Dec 16, 2025.
        //
        // Calling uninstall will flush the data, allowing us to assert the client invocations
        try getIntegration()?.uninstall()
    }

    // Helper to get captured metrics
    // Note: The buffer produces JSON in the format {"items":[...]} as verified by InMemoryInternalTelemetryBuffer.batchedData
    //
    // Design decision: We use JSONSerialization instead of:
    // 1. Decodable: Would introduce decoding logic in tests that could be wrong, creating a risk that tests pass
    //    even when the actual encoding/decoding logic is broken.
    // 2. Direct string comparison: JSON key ordering is not guaranteed, so tests would be flaky.
    //
    // JSONSerialization provides a good middle ground: it parses the JSON structure without duplicating
    // the encoding/decoding logic, and it's order-agnostic, making tests stable while still verifying
    // the actual data structure produced by the buffer.
    private func getCapturedMetrics(from client: TestClient) -> [[String: Any]] {
        var allMetrics: [[String: Any]] = []
        
        for invocation in client.captureMetricsDataInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    allMetrics.append(item)
                }
            }
        }
        
        return allMetrics
    }
}
