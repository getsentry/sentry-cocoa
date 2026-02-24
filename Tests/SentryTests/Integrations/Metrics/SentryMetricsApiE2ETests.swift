import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// End-to-end tests for the SentryMetricsApi. These tests use the public API
/// (`SentrySDK.metrics.count/distribution/gauge`) and assert that the correct
/// `SentryMetric` structs arrive in the telemetry processor's metrics buffer.
class SentryMetricsApiE2ETests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests - Count

    func testCount_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.count(key: "network.request.count", value: 1)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "network.request.count")
        XCTAssertEqual(metric.value, .counter(1))
    }

    func testCount_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: SentrySDKInternal.currentHub().scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)

        // -- Act --
        SentrySDK.metrics.count(key: "test.metric", value: 1)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testCount_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub(isMetricsEnabled: false)

        // -- Act --
        SentrySDK.metrics.count(key: "test.metric", value: 1)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testCount_withZeroValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.count(key: "button.click", value: 0)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "button.click")
        XCTAssertEqual(metric.value, .counter(0))
    }

    func testCount_withLargeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.count(key: "events.processed", value: 1_000_000_000)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "events.processed")
        XCTAssertEqual(metric.value, .counter(1_000_000_000))
    }

    func testCount_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

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

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "api.request.count")
        XCTAssertEqual(metric.value, .counter(1))
        XCTAssertEqual(metric.attributes["endpoint"]?.anyValue as? String, "api/users")
        XCTAssertEqual(metric.attributes["success"]?.anyValue as? Bool, true)
        XCTAssertEqual(metric.attributes["status_code"]?.anyValue as? Int, 200)
        XCTAssertEqual(try XCTUnwrap(metric.attributes["response_time"]?.anyValue as? Double), 0.125, accuracy: 0.001)
    }

    // MARK: - Tests - Distribution

    func testDistribution_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.distribution(key: "http.request.duration", value: 187.5)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "http.request.duration")
        XCTAssertEqual(metric.value, .distribution(187.5))
    }

    func testDistribution_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: SentrySDKInternal.currentHub().scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)

        // -- Act --
        SentrySDK.metrics.distribution(key: "test.metric", value: 1.0)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testDistribution_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub(isMetricsEnabled: false)

        // -- Act --
        SentrySDK.metrics.distribution(key: "test.metric", value: 1.0)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testDistribution_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.distribution(key: "latency", value: -10.5)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "latency")
        XCTAssertEqual(metric.value, .distribution(-10.5))
    }

    func testDistribution_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.distribution(
            key: "db.query.duration",
            value: 45.7,
            attributes: [
                "database": "postgres",
                "cached": false
            ]
        )

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "db.query.duration")
        XCTAssertEqual(metric.value, .distribution(45.7))
        XCTAssertEqual(metric.attributes["database"]?.anyValue as? String, "postgres")
        XCTAssertEqual(metric.attributes["cached"]?.anyValue as? Bool, false)
    }

    // MARK: - Tests - Gauge

    func testGauge_withValidKeyAndValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.gauge(key: "memory.usage", value: 1_024.0)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "memory.usage")
        XCTAssertEqual(metric.value, .gauge(1_024.0))
    }

    func testGauge_withSDKDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()
        let hubWithoutClient = SentryHubInternal(client: nil, andScope: SentrySDKInternal.currentHub().scope)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)

        // -- Act --
        SentrySDK.metrics.gauge(key: "test.metric", value: 1.0)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testGauge_withMetricsDisabled_shouldNotCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub(isMetricsEnabled: false)

        // -- Act --
        SentrySDK.metrics.gauge(key: "test.metric", value: 1.0)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0)
    }

    func testGauge_withNegativeValue_shouldCreateMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.gauge(key: "temperature", value: -5.0)

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "temperature")
        XCTAssertEqual(metric.value, .gauge(-5.0))
    }

    func testGauge_withAttributes_shouldCreateMetricWithAttributes() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()

        // -- Act --
        SentrySDK.metrics.gauge(
            key: "system.cpu.usage",
            value: 75.5,
            attributes: [
                "process": "main_app",
                "core_count": 8,
                "utilization": 0.755
            ]
        )

        // -- Assert --
        let metric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(metric.name, "system.cpu.usage")
        XCTAssertEqual(metric.value, .gauge(75.5))
        XCTAssertEqual(metric.attributes["process"]?.anyValue as? String, "main_app")
        XCTAssertEqual(metric.attributes["core_count"]?.anyValue as? Int, 8)
        XCTAssertEqual(try XCTUnwrap(metric.attributes["utilization"]?.anyValue as? Double), 0.755, accuracy: 0.001)
    }

    // MARK: - Helpers

    @discardableResult
    private func givenSdkWithHub(isMetricsEnabled: Bool = true) throws -> E2EMetricsTestClient {
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.removeAllIntegrations()
        options.experimental.enableMetrics = isMetricsEnabled

        let client = try XCTUnwrap(E2EMetricsTestClient(options: options))
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )

        SentrySDK.setStart(with: options)
        SentrySDKInternal.setCurrentHub(hub)

        if isMetricsEnabled {
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
        return client
    }
}

// MARK: - Test Doubles

private class E2EMetricsTestClient: TestClient {
    let testMetricsBuffer = E2ETestMetricsTelemetryBuffer()

    private lazy var testProcessor: SentryDefaultTelemetryProcessor = {
        SentryDefaultTelemetryProcessor(
            logBuffer: E2ENoOpLogTelemetryBuffer(),
            metricsBuffer: testMetricsBuffer
        )
    }()

    override func getTelemetryProcessor() -> Any {
        return testProcessor
    }
}

private final class E2ETestMetricsTelemetryBuffer: TelemetryBuffer {
    var addInvocations = Invocations<SentryMetric>()

    func add(_ item: SentryMetric) {
        addInvocations.record(item)
    }

    @discardableResult
    func capture() -> TimeInterval { 0.0 }
}

private final class E2ENoOpLogTelemetryBuffer: TelemetryBuffer {
    func add(_ item: SentryLog) {}
    @discardableResult func capture() -> TimeInterval { 0.0 }
}
