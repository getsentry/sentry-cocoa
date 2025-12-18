import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMetricsApiTests: XCTestCase {
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "network.request.count", "Metric key should match")
       XCTAssertEqual(metric.value.integerValue, 1, "Metric value should match")
       XCTAssertEqual(metric.type, .counter, "Metric type should be counter")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "button.click", "Metric key should match")
       XCTAssertEqual(metric.value.integerValue, 0, "Metric value should be zero")
       XCTAssertEqual(metric.type, .counter, "Metric type should be counter")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "events.processed", "Metric key should match")
       XCTAssertEqual(metric.value.integerValue, 1_000_000_000, "Metric value should match large value")
       XCTAssertEqual(metric.type, .counter, "Metric type should be counter")
   }

   func testCount_withNegativeValue_shouldCreateMetric() throws {
       // -- Arrange --
       try givenSdkWithHub()
       let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")

       // -- Act --
       SentrySDK.metrics.count(key: "error.count", value: -1)
       try flushMetrics()

       // -- Assert --
       let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first, "Metrics should be created for negative values")
       XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "error.count", "Metric key should match")
       XCTAssertEqual(metric.value.integerValue, -1, "Metric value should match negative value")
       XCTAssertEqual(metric.type, .counter, "Metric type should be counter")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "api.request.count", "Metric key should match")
       XCTAssertEqual(metric.value.integerValue, 1, "Metric value should match")
       XCTAssertEqual(metric.type, .counter, "Metric type should be counter")

       let endpointAttr = try XCTUnwrap(metric.attributes["endpoint"], "endpoint attribute should exist")
       XCTAssertEqual(endpointAttr.value as? String, "api/users", "endpoint attribute value should match")
       
       let successAttr = try XCTUnwrap(metric.attributes["success"], "success attribute should exist")
       XCTAssertEqual(successAttr.value as? Bool, true, "success attribute value should match")
       
       let statusCodeAttr = try XCTUnwrap(metric.attributes["status_code"], "status_code attribute should exist")
       XCTAssertEqual(statusCodeAttr.value as? Int, 200, "status_code attribute value should match")
       
       let responseTimeAttr = try XCTUnwrap(metric.attributes["response_time"], "response_time attribute should exist")
       XCTAssertEqual(try XCTUnwrap(responseTimeAttr.value as? Double), 0.125, accuracy: 0.001, "response_time attribute value should match")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "http.request.duration", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 187.5, accuracy: 0.001, "Metric value should match")
       XCTAssertEqual(metric.type, .distribution, "Metric type should be distribution")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "response.time", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 0.0, accuracy: 0.001, "Metric value should be zero")
       XCTAssertEqual(metric.type, .distribution, "Metric type should be distribution")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "processing.duration", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 999_999.99, accuracy: 0.01, "Metric value should match large value")
       XCTAssertEqual(metric.type, .distribution, "Metric type should be distribution")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "latency", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, -10.5, accuracy: 0.001, "Metric value should match negative value")
       XCTAssertEqual(metric.type, .distribution, "Metric type should be distribution")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "db.query.duration", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 45.7, accuracy: 0.001, "Metric value should match")
       XCTAssertEqual(metric.type, .distribution, "Metric type should be distribution")

       let databaseAttr = try XCTUnwrap(metric.attributes["database"], "database attribute should exist")
       XCTAssertEqual(databaseAttr.value as? String, "postgres", "database attribute value should match")
       
       let cachedAttr = try XCTUnwrap(metric.attributes["cached"], "cached attribute should exist")
       XCTAssertEqual(cachedAttr.value as? Bool, false, "cached attribute value should match")
       
       let queryCountAttr = try XCTUnwrap(metric.attributes["query_count"], "query_count attribute should exist")
       XCTAssertEqual(queryCountAttr.value as? Int, 3, "query_count attribute value should match")
       
       let cacheHitRateAttr = try XCTUnwrap(metric.attributes["cache_hit_rate"], "cache_hit_rate attribute should exist")
       XCTAssertEqual(try XCTUnwrap(cacheHitRateAttr.value as? Double), 0.85, accuracy: 0.001, "cache_hit_rate attribute value should match")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "memory.usage", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 1_024.0, accuracy: 0.001, "Metric value should match")
       XCTAssertEqual(metric.type, .gauge, "Metric type should be gauge")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "queue.depth", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 0.0, accuracy: 0.001, "Metric value should be zero")
       XCTAssertEqual(metric.type, .gauge, "Metric type should be gauge")
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
       
       let metrics = try getCapturedMetrics(from: client)
       XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
       let metric = try XCTUnwrap(metrics.element(at: 0))
       XCTAssertEqual(metric.name, "active.connections", "Metric key should match")
       XCTAssertEqual(metric.value.doubleValue, 50_000.0, accuracy: 0.001, "Metric value should match large value")
       XCTAssertEqual(metric.type, .gauge, "Metric type should be gauge")
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
        
        let metrics = try getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.element(at: 0))
        XCTAssertEqual(metric.name, "temperature", "Metric key should match")
        XCTAssertEqual(metric.value.doubleValue, -5.0, accuracy: 0.001, "Metric value should match negative value")
        XCTAssertEqual(metric.type, .gauge, "Metric type should be gauge")
        
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
        
        let metrics = try getCapturedMetrics(from: client)
        XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
        let metric = try XCTUnwrap(metrics.element(at: 0))
        XCTAssertEqual(metric.name, "system.cpu.usage", "Metric key should match")
        XCTAssertEqual(metric.value.doubleValue, 75.5, accuracy: 0.001, "Metric value should match")
        XCTAssertEqual(metric.type, .gauge, "Metric type should be gauge")

        let processAttr = try XCTUnwrap(metric.attributes["process"], "process attribute should exist")
        XCTAssertEqual(processAttr.value as? String, "main_app", "process attribute value should match")
        
        let compressedAttr = try XCTUnwrap(metric.attributes["compressed"], "compressed attribute should exist")
        XCTAssertEqual(compressedAttr.value as? Bool, true, "compressed attribute value should match")
        
        let coreCountAttr = try XCTUnwrap(metric.attributes["core_count"], "core_count attribute should exist")
        XCTAssertEqual(coreCountAttr.value as? Int, 8, "core_count attribute value should match")
        
        let utilizationAttr = try XCTUnwrap(metric.attributes["utilization"], "utilization attribute should exist")
        XCTAssertEqual(try XCTUnwrap(utilizationAttr.value as? Double), 0.755, accuracy: 0.001, "utilization attribute value should match")
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
                ) as? SentryIntegrationProtocol
            )
            hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<SentryDependencyContainer>.name)
        }

        hub.startSession()
    }

    private func getIntegration() throws -> SentryMetricsIntegration<SentryDependencyContainer>? {
        return SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration
    }

    private func flushMetrics() throws {
        // We can not rely on the SentrySDK.flush(), because we are using a test client which is not actually
        // flushing integrations as of Dec 16, 2025.
        //
        // Calling uninstall will flush the data, allowing us to assert the client invocations
        try getIntegration()?.uninstall()
    }
    
    private func getCapturedMetrics(from client: TestClient) throws -> [ParsedMetric] {
        var allMetrics: [ParsedMetric] = []
        
        for invocation in client.captureMetricsDataInvocations.invocations {
            guard let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
                  let items = jsonObject["items"] as? [[String: Any]] else {
                continue
            }
            
            for item in items {
                if let metric = try parseMetric(from: item) {
                    allMetrics.append(metric)
                }
            }
        }
        
        return allMetrics
    }
    
    private func parseMetric(from dict: [String: Any]) throws -> ParsedMetric? {
        guard let name = dict["name"] as? String,
              let typeString = dict["type"] as? String,
              let type = parseMetricType(typeString) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: (dict["timestamp"] as? TimeInterval) ?? 0)
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)
        
        // Decode value - can be Int64 or Double
        let value: SentryMetricValue
        if let intValue = dict["value"] as? Int64 {
            value = .integer(intValue)
        } else if let doubleValue = dict["value"] as? Double {
            value = .double(doubleValue)
        } else if let intValue = dict["value"] as? Int {
            value = .integer(Int64(intValue))
        } else {
            return nil
        }
        
        let unit = dict["unit"] as? String
        
        var attributes: [String: SentryMetric.Attribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, attrValue) in attributesDict {
                if let attrVal = attrValue["value"] {
                    attributes[key] = SentryMetric.Attribute(value: attrVal)
                }
            }
        }
        
        return ParsedMetric(
            timestamp: timestamp,
            traceId: traceId,
            name: name,
            value: value,
            type: type,
            unit: unit,
            attributes: attributes
        )
    }
    
    private func parseMetricType(_ string: String) -> SentryMetricType? {
        switch string {
        case "counter":
            return .counter
        case "gauge":
            return .gauge
        case "distribution":
            return .distribution
        default:
            return nil
        }
    }
}

// MARK: - ParsedMetric Helper

private struct ParsedMetric {
    let timestamp: Date
    let traceId: SentryId
    let name: String
    let value: SentryMetricValue
    let type: SentryMetricType
    let unit: String?
    let attributes: [String: SentryMetric.Attribute]
}

extension SentryMetricValue {
    var integerValue: Int64 {
        switch self {
        case .integer(let value):
            return value
        case .double(let value):
            return Int64(value)
        }
    }
    
    var doubleValue: Double {
        switch self {
        case .integer(let value):
            return Double(value)
        case .double(let value):
            return value
        }
    }
}
