import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// This test suite tests the SentryMetricsApi on a unit test level to verify the logic without bootstrapping an entire SDK setup.
///
/// Having additional unit tests can help pin down if failing end-to-end tests are caused by unrelated internal programming errors.
final class SentryMetricsApiTests: XCTestCase {
    private let scope = Scope()

    // MARK: - Count

    func testCount_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "network.request.count", value: 1)

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "network.request.count", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1), "Metric value should match")
        XCTAssertNil(metric.unit, "Metric unit should be nil")
        XCTAssertTrue(metric.attributes.isEmpty, "Metric attributes should be empty")

        let invokedScope: Scope = invocation.1
        XCTAssertEqual(invokedScope, scope, "Scope should be passed to the integration")
    }

    func testCount_withUnit_shouldCreateMetricWithUnit() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "network.request.count", value: 1, unit: "requests")

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "network.request.count", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1), "Metric value should match")
        XCTAssertEqual(metric.unit, "requests", "Metric unit should be set")
        XCTAssertTrue(metric.attributes.isEmpty, "Metric attributes should be empty")

        let invokedScope: Scope = invocation.1
        XCTAssertEqual(invokedScope, scope, "Scope should be passed to the integration")
    }

    func testCount_withAtributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "network.request.count", value: 1, attributes: [
            "other-key": "other-value"
        ])

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "network.request.count", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1), "Metric value should match")
        XCTAssertNil(metric.unit, "Metric unit should be nil")
        XCTAssertEqual(metric.attributes["other-key"]?.anyValue as? String, "other-value", "Custom metric attributes should be set")

        let invokedScope: Scope = invocation.1
        XCTAssertEqual(invokedScope, scope, "Scope should be passed to the integration")
    }

    func testCount_withUnitAndAtributes_shouldCreateMetricWithUnitAndAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "network.request.count", value: 1, unit: "requests", attributes: [
            "other-key": "other-value"
        ])

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "network.request.count", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1), "Metric value should match")
        XCTAssertEqual(metric.unit, "requests", "Metric unit should be nil")
        XCTAssertEqual(metric.attributes["other-key"]?.anyValue as? String, "other-value", "Custom metric attributes should be set")

        let invokedScope: Scope = invocation.1
        XCTAssertEqual(invokedScope, scope, "Scope should be passed to the integration")
    }

    func testCount_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: false,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count(key: "test.metric", value: 1)
        
        // -- Assert --
        XCTAssertEqual(dependencies.metricsIntegration?.addMetricInvocations.count, 0, "No metrics should be created when SDK is disabled")
    }
    
    func testCount_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: nil
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count(key: "test.metric", value: 1)
        
        // -- Assert --
        // When metricsIntegration is nil (metrics disabled), the API returns early without
        // recording any metrics. Since the integration is nil, there's no mock to verify
        // invocations on - the assertion confirms the test precondition and that no crash occurred.
        XCTAssertNil(dependencies.metricsIntegration, "Integration is nil, so there's nothing to assert invocations on")
    }
    
    func testCount_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count(key: "button.click", value: 0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "button.click", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(0), "Metric value should be zero")
    }
    
    func testCount_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count(key: "events.processed", value: 1_000_000_000)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "events.processed", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1_000_000_000), "Metric value should match large value")
    }
    
    func testCount_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count(
            key: "api.request.count",
            value: 1,
            attributes: [
                "endpoint": "api/users",
                "success": true,
                "status_code": 200,
                "response_time": 0.125
            ]
        )
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "api.request.count", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.counter(1), "Metric value should match")
        
        XCTAssertEqual(metric.attributes["endpoint"]?.anyValue as? String, "api/users", "endpoint attribute value should match")
        XCTAssertEqual(metric.attributes["success"]?.anyValue as? Bool, true, "success attribute value should match")
        XCTAssertEqual(metric.attributes["status_code"]?.anyValue as? Int, 200, "status_code attribute value should match")
        XCTAssertEqual(try XCTUnwrap(metric.attributes["response_time"]?.anyValue as? Double), 0.125, accuracy: 0.001, "response_time attribute value should match")
    }
    
    // MARK: - Distribution
    
    func testDistribution_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "http.request.duration", value: 187.5)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "http.request.duration", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.distribution(187.5), "Metric value should match")
    }
    
    func testDistribution_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: false,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "test.metric", value: 1.0)
        
        // -- Assert --
        XCTAssertEqual(dependencies.metricsIntegration?.addMetricInvocations.count, 0, "No metrics should be captured when SDK is disabled")
    }
    
    func testDistribution_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: nil
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "test.metric", value: 1.0)
        
        // -- Assert --
        // When metricsIntegration is nil (metrics disabled), the API returns early without
        // recording any metrics. Since the integration is nil, there's no mock to verify
        // invocations on - the assertion confirms the test precondition and that no crash occurred.
        XCTAssertNil(dependencies.metricsIntegration, "Integration is nil, so there's nothing to assert invocations on")
    }
    
    func testDistribution_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "response.time", value: 0.0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "response.time", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.distribution(0.0), "Metric value should be zero")
    }
    
    func testDistribution_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "processing.duration", value: 999_999.99)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "processing.duration", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.distribution(999_999.99), "Metric value should match large value")
    }
    
    func testDistribution_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(key: "latency", value: -10.5)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "latency", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.distribution(-10.5), "Metric value should match negative value")
    }
    
    func testDistribution_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.distribution(
            key: "db.query.duration",
            value: 45.7,
            attributes: [
                "database": "postgres",
                "cached": false,
                "query_count": 3,
                "cache_hit_rate": 0.85
            ]
        )
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "db.query.duration", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.distribution(45.7), "Metric value should match")
        
        XCTAssertEqual(metric.attributes["database"]?.anyValue as? String, "postgres", "database attribute value should match")
        XCTAssertEqual(metric.attributes["cached"]?.anyValue as? Bool, false, "cached attribute value should match")
        XCTAssertEqual(metric.attributes["query_count"]?.anyValue as? Int, 3, "query_count attribute value should match")
        XCTAssertEqual(try XCTUnwrap(metric.attributes["cache_hit_rate"]?.anyValue as? Double), 0.85, accuracy: 0.001, "cache_hit_rate attribute value should match")
    }
    
    // MARK: - Gauge
    
    func testGauge_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "memory.usage", value: 1_024.0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "memory.usage", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.gauge(1_024.0), "Metric value should match")
    }
    
    func testGauge_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: false,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "test.metric", value: 1.0)
        
        // -- Assert --
        XCTAssertEqual(dependencies.metricsIntegration?.addMetricInvocations.count, 0, "No metrics should be captured when SDK is disabled")
    }
    
    func testGauge_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: nil
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "test.metric", value: 1.0)
        
        // -- Assert --
        // When metricsIntegration is nil (metrics disabled), the API returns early without
        // recording any metrics. Since the integration is nil, there's no mock to verify
        // invocations on - the assertion confirms the test precondition and that no crash occurred.
        XCTAssertNil(dependencies.metricsIntegration, "Integration is nil, so there's nothing to assert invocations on")
    }
    
    func testGauge_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "queue.depth", value: 0.0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "queue.depth", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.gauge(0.0), "Metric value should be zero")
    }
    
    func testGauge_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "active.connections", value: 50_000.0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "active.connections", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.gauge(50_000.0), "Metric value should match large value")
    }
    
    func testGauge_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(key: "temperature", value: -5.0)
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "temperature", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.gauge(-5.0), "Metric value should match negative value")
    }
    
    func testGauge_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.gauge(
            key: "system.cpu.usage",
            value: 75.5,
            attributes: [
                "process": "main_app",
                "compressed": true,
                "core_count": 8,
                "utilization": 0.755
            ]
        )
        
        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        let metric: SentryMetric = invocation.0
        XCTAssertEqual(metric.name, "system.cpu.usage", "Metric key should match")
        XCTAssertEqual(metric.value, SentryMetric.Value.gauge(75.5), "Metric value should match")
        
        XCTAssertEqual(metric.attributes["process"]?.anyValue as? String, "main_app", "process attribute value should match")
        XCTAssertEqual(metric.attributes["compressed"]?.anyValue as? Bool, true, "compressed attribute value should match")
        XCTAssertEqual(metric.attributes["core_count"]?.anyValue as? Int, 8, "core_count attribute value should match")
        XCTAssertEqual(try XCTUnwrap(metric.attributes["utilization"]?.anyValue as? Double), 0.755, accuracy: 0.001, "utilization attribute value should match")
    }
}

// MARK: - Mock Dependencies

fileprivate struct MockMetricsIntegration: SentryMetricsIntegrationProtocol {
    var addMetricInvocations = Invocations<(SentryMetric, Scope)>()
    func addMetric(_ metric: Sentry.SentryMetric, scope: Scope) {
        addMetricInvocations.record((metric, scope))
    }
}

fileprivate struct MockMetricsApiDependencies: SentryMetricsApiDependencies {
    let isSDKEnabled: Bool
    let scope: Scope
    let dateProvider: SentryCurrentDateProvider
    let metricsIntegration: MockMetricsIntegration?

    init(
        isSDKEnabled: Bool,
        scope: Scope,
        metricsIntegration: MockMetricsIntegration?,
        dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider()
    ) {
        self.isSDKEnabled = isSDKEnabled
        self.scope = scope
        self.dateProvider = dateProvider
        self.metricsIntegration = metricsIntegration
    }
}
