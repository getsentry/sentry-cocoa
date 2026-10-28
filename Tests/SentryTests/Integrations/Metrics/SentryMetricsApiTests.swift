@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
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
        sut.count("network.request.count", value: 1)

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

    func testCount_withAtributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count("network.request.count", value: 1, options: SentryMetricOptions(attributes: [
            "other-key": "other-value"
        ]))

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

    func testCount_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: false,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        
        // -- Act --
        sut.count("test.metric", value: 1)
        
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
        sut.count("test.metric", value: 1)
        
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
        sut.count("button.click", value: 0)
        
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
        sut.count("events.processed", value: 1_000_000_000)
        
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
            "api.request.count",
            value: 1,
            options: SentryMetricOptions(
                attributes: [
                    "endpoint": "api/users",
                    "success": true,
                    "status_code": 200,
                    "response_time": 0.125
                ]
            )
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
        sut.distribution("http.request.duration", value: 187.5)
        
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
        sut.distribution("test.metric", value: 1.0)
        
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
        sut.distribution("test.metric", value: 1.0)
        
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
        sut.distribution("response.time", value: 0.0)
        
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
        sut.distribution("processing.duration", value: 999_999.99)
        
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
        sut.distribution("latency", value: -10.5)
        
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
            "db.query.duration",
            value: 45.7,
            options: SentryMetricOptions(
                attributes: [
                    "database": "postgres",
                    "cached": false,
                    "query_count": 3,
                    "cache_hit_rate": 0.85
                ]
            )
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
        sut.gauge("memory.usage", value: 1_024.0)
        
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
        sut.gauge("test.metric", value: 1.0)
        
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
        sut.gauge("test.metric", value: 1.0)
        
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
        sut.gauge("queue.depth", value: 0.0)
        
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
        sut.gauge("active.connections", value: 50_000.0)
        
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
        sut.gauge("temperature", value: -5.0)
        
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
            "system.cpu.usage",
            value: 75.5,
            options: SentryMetricOptions(
                attributes: [
                    "process": "main_app",
                    "compressed": true,
                    "core_count": 8,
                    "utilization": 0.755
                ]
            )
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

    // MARK: - withCurrentScope

    func testCount_withCurrentScope_passesCurrentScopeToIntegration() throws {
        let storage = SentryCurrentScopeStorage()
        let currentScope = Scope()
        currentScope.setTag(value: "scoped", key: "tag")

        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: Scope(),
            metricsIntegration: MockMetricsIntegration(),
            currentScopeStorage: storage
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        storage.withScope(currentScope) {
            sut.count("test.count")
        }

        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertNotNil(invocation.currentScope)
        XCTAssertEqual(invocation.currentScope?.tags["tag"], "scoped")
    }

    func testCount_withoutCurrentScope_passesNil() throws {
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: Scope(),
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        sut.count("test.count")

        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertNil(invocation.currentScope)
    }

    func testCount_withOptionsScope_passesOptionsScopeAsCurrentScope() throws {
        // -- Arrange --
        let storage = SentryCurrentScopeStorage()
        let threadScope = Scope()
        let optionsScope = Scope()
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            currentScopeStorage: storage
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        storage.withScope(threadScope) {
            sut.count("test.count", value: 1, options: SentryMetricOptions(scope: optionsScope))
        }

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertIdentical(invocation.currentScope, optionsScope, "The options scope should replace the thread's current scope")
        XCTAssertIdentical(invocation.scope, scope, "The global scope should still be passed to the integration")
    }

    // MARK: - Options

    func testCount_withOptionsTimestamp_shouldUseTimestamp() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 2_000))
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            dateProvider: dateProvider
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count("test.count", value: 1, options: SentryMetricOptions(timestamp: timestamp))
        sut.distribution("test.distribution", value: 1, options: SentryMetricOptions(timestamp: timestamp))
        sut.gauge("test.gauge", value: 1, options: SentryMetricOptions(timestamp: timestamp))

        // -- Assert --
        let metrics = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.invocations.map(\.metric))
        XCTAssertEqual(metrics.map(\.timestamp), [timestamp, timestamp, timestamp])
    }

    func testCount_withoutOptionsTimestamp_shouldUseCurrentDate() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let now = Date(timeIntervalSince1970: 2_000)
        dateProvider.setDate(date: now)
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            dateProvider: dateProvider
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count("test.count")

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertEqual(invocation.metric.timestamp, now)
    }

    func testCount_withOptionsUnit_shouldIgnoreUnit() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count("test.count", value: 1, options: SentryMetricOptions(unit: .millisecond))

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertNil(invocation.metric.unit, "Count metrics have no unit")
    }

    // MARK: - Internal API timestamp

    func testCount_withTimestamp_shouldUseTimestamp() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 1_800_000_000))
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            dateProvider: dateProvider
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        let timestamp = Date(timeIntervalSince1970: 1_799_913_600)

        // -- Act --
        sut.count(key: "network.request.count", value: 3, timestamp: timestamp, attributes: ["endpoint": "/api/users"])

        // -- Assert --
        let metric = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first?.metric)
        XCTAssertEqual(metric.timestamp, timestamp)
        XCTAssertEqual(metric.name, "network.request.count")
        XCTAssertEqual(metric.value, .counter(3))
        XCTAssertNil(metric.unit)
        XCTAssertEqual(metric.attributes["endpoint"]?.anyValue as? String, "/api/users")
    }

    func testDistribution_withTimestamp_shouldUseTimestamp() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 1_800_000_000))
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            dateProvider: dateProvider
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        let timestamp = Date(timeIntervalSince1970: 1_799_913_600)

        // -- Act --
        sut.distribution(key: "app.launch.time", value: 1.25, unit: .second, timestamp: timestamp)

        // -- Assert --
        let metric = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first?.metric)
        XCTAssertEqual(metric.timestamp, timestamp)
        XCTAssertEqual(metric.name, "app.launch.time")
        XCTAssertEqual(metric.value, .distribution(1.25))
        XCTAssertEqual(metric.unit, .second)
    }

    func testGauge_withTimestamp_shouldUseTimestamp() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 1_800_000_000))
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration(),
            dateProvider: dateProvider
        )
        let sut = SentryMetricsApi(dependencies: dependencies)
        let timestamp = Date(timeIntervalSince1970: 1_799_913_600)

        // -- Act --
        sut.gauge(key: "memory.peak", value: 512, unit: .megabyte, timestamp: timestamp)

        // -- Assert --
        let metric = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first?.metric)
        XCTAssertEqual(metric.timestamp, timestamp)
        XCTAssertEqual(metric.name, "memory.peak")
        XCTAssertEqual(metric.value, .gauge(512))
        XCTAssertEqual(metric.unit, .megabyte)
    }

    func testCount_withTimestampAndSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: false,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "network.request.count", value: 1, timestamp: Date(timeIntervalSince1970: 1_799_913_600))

        // -- Assert --
        XCTAssertEqual(dependencies.metricsIntegration?.addMetricInvocations.count, 0)
    }

    // MARK: - Overriding Attributes

    func testCount_withoutOverridingAttributes_shouldPassEmptyOverridingAttributes() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count("network.request.count", value: 1, options: SentryMetricOptions(attributes: ["endpoint": "/api/users"]))

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertTrue(invocation.overridingAttributes.isEmpty)
    }

    func testCount_withOverridingAttributes_shouldPassThemSeparately() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(
            key: "network.request.count",
            value: 1,
            timestamp: Date(timeIntervalSince1970: 1_799_913_600),
            attributes: ["endpoint": "/api/users"],
            overridingAttributes: ["sentry.release": "io.sentry.app@1.0.0+1"]
        )

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertEqual(invocation.overridingAttributes, ["sentry.release": .string("io.sentry.app@1.0.0+1")])
        XCTAssertNil(invocation.metric.attributes["sentry.release"])
        XCTAssertEqual(invocation.metric.attributes["endpoint"], .string("/api/users"))
    }

    func testDistribution_withOverridingAttributes_shouldPassThemSeparately() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.distribution(
            key: "app.launch.time",
            value: 1.25,
            unit: .second,
            timestamp: Date(timeIntervalSince1970: 1_799_913_600),
            overridingAttributes: ["os.version": "18.6.2"]
        )

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertEqual(invocation.overridingAttributes, ["os.version": .string("18.6.2")])
    }

    func testGauge_withOverridingAttributes_shouldPassThemSeparately() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.gauge(
            key: "memory.peak",
            value: 512,
            unit: .megabyte,
            timestamp: Date(timeIntervalSince1970: 1_799_913_600),
            overridingAttributes: ["os.version": "18.6.2"]
        )

        // -- Assert --
        let invocation = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.first)
        XCTAssertEqual(invocation.overridingAttributes, ["os.version": .string("18.6.2")])
    }

    #if !SDK_V10
    // MARK: - Deprecated key-based API

    @available(*, deprecated, message: "Testing the deprecated key-based API")
    func testDeprecatedKeyBasedApi_shouldForwardToOptionsApi() throws {
        // -- Arrange --
        let dependencies = MockMetricsApiDependencies(
            isSDKEnabled: true,
            scope: scope,
            metricsIntegration: MockMetricsIntegration()
        )
        let sut: SentryMetricsApiProtocol = SentryMetricsApi(dependencies: dependencies)

        // -- Act --
        sut.count(key: "test.count", value: 2, attributes: ["a": "b"])
        sut.distribution(key: "test.distribution", value: 3, unit: .millisecond, attributes: ["c": 1])
        sut.gauge(key: "test.gauge", value: 4, unit: .byte, attributes: ["d": true])

        // -- Assert --
        let metrics = try XCTUnwrap(dependencies.metricsIntegration?.addMetricInvocations.invocations.map(\.metric))
        XCTAssertEqual(metrics.map(\.name), ["test.count", "test.distribution", "test.gauge"])
        XCTAssertEqual(metrics.map(\.value), [.counter(2), .distribution(3), .gauge(4)])
        XCTAssertEqual(metrics.map(\.unit), [nil, .millisecond, .byte])
        XCTAssertEqual(metrics[0].attributes["a"]?.anyValue as? String, "b")
        XCTAssertEqual(metrics[1].attributes["c"]?.anyValue as? Int, 1)
        XCTAssertEqual(metrics[2].attributes["d"]?.anyValue as? Bool, true)
    }

    @available(*, deprecated, message: "Testing the deprecated key-based API")
    func testLegacyConformer_optionsApi_shouldFallBackToKeyBasedRequirements() throws {
        // -- Arrange --
        let sut = LegacyMetricsApi()

        // -- Act --
        sut.count("test.count", value: 2, options: SentryMetricOptions(attributes: ["a": "b"]))
        sut.distribution("test.distribution", value: 3, options: SentryMetricOptions(unit: .millisecond))
        sut.gauge("test.gauge", value: 4)

        // -- Assert --
        XCTAssertEqual(sut.invocations.map(\.key), ["test.count", "test.distribution", "test.gauge"])
        XCTAssertEqual(sut.invocations.map(\.value), [2, 3, 4])
        XCTAssertEqual(sut.invocations.map(\.unit), [nil, .millisecond, nil])
        XCTAssertEqual(sut.invocations[0].attributes["a"] as? String, "b")
    }
    #endif // !SDK_V10
}

// MARK: - Mock Dependencies

fileprivate struct MockMetricsIntegration: SentryMetricsIntegrationProtocol {
    var addMetricInvocations = Invocations<(metric: SentryMetric, scope: Scope, currentScope: Scope?, overridingAttributes: [String: SentryAttributeContent])>()
    func addMetric(_ metric: SentryMetric, scope: Scope, currentScope: Scope? = nil, overridingAttributes: [String: SentryAttributeContent] = [:]) {
        addMetricInvocations.record((metric, scope, currentScope, overridingAttributes))
    }
}

fileprivate struct MockMetricsApiDependencies: SentryMetricsApiDependencies {
    let isSDKEnabled: Bool
    let scope: Scope
    let dateProvider: SentryCurrentDateProvider
    let currentScopeStorage: SentryCurrentScopeStorage
    let metricsIntegration: MockMetricsIntegration?

    init(
        isSDKEnabled: Bool,
        scope: Scope,
        metricsIntegration: MockMetricsIntegration?,
        dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider(),
        currentScopeStorage: SentryCurrentScopeStorage = SentryCurrentScopeStorage()
    ) {
        self.isSDKEnabled = isSDKEnabled
        self.scope = scope
        self.dateProvider = dateProvider
        self.currentScopeStorage = currentScopeStorage
        self.metricsIntegration = metricsIntegration
    }
}

#if !SDK_V10
/// A conformer written before the options-based requirements existed.
@available(*, deprecated, message: "Testing the deprecated key-based API")
fileprivate final class LegacyMetricsApi: SentryMetricsApiProtocol {
    var invocations: [(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue])] = []

    func count(key: String, value: UInt, attributes: [String: SentryAttributeValue]) {
        invocations.append((key, Double(value), nil, attributes))
    }

    func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        invocations.append((key, value, unit, attributes))
    }

    func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        invocations.append((key, value, unit, attributes))
    }
}
#endif // !SDK_V10
