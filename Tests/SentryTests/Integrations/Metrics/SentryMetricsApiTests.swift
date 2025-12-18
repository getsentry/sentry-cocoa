import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMetricsApiTests: XCTestCase {
    private var client: TestClient!
    private var hub: SentryHubInternal!

    override func setUpWithError() throws {
        super.setUp()

        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: SentryMetricsApiTests.self)
        options.removeAllIntegrations()
        options.experimental.enableMetrics = true

        client = try XCTUnwrap(TestClient(options: options))
        hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests - Count

    func testCount_withValidKeyAndValue_shouldCreateMetric() {
        // -- Arrange --
        startSDK()
        let sut = SentryMetricsApi()
        let key = "network.request.count"
        let value = 1

        // -- Act --
        sut.count(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertGreaterThanOrEqual(getMetricDataCount(), 1, "Metric should be created when SDK is enabled")
    }
    
    func testCount_withSDKEnabled_CreatesMetric() {
        // -- Arrange --
        startSDK()
        let sut = SentryMetricsApi()
        
        // -- Act --
        sut.count(key: "test.metric", value: 1)
        flushMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(getMetricDataCount(), 1, "Metric should be created when SDK is enabled")
    }
    
    func testCount_withMetricsDisabled_DoesNotCreateMetric() {
        // -- Arrange --
        startSDK(enableMetrics: false)
        let sut = SentryMetricsApi()
        
        // -- Act --
        sut.count(key: "test.metric", value: 1)
        flushMetrics()
        
        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when metrics are disabled")
    }
    
    func testDistribution_withSDKEnabled_CreatesMetric() {
        // -- Arrange --
        startSDK()
        let sut = SentryMetricsApi()
        
        // -- Act --
        sut.distribution(key: "test.distribution", value: 125.5, unit: "millisecond")
        flushMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(getMetricDataCount(), 1, "Metric should be created when SDK is enabled")
    }
    
    func testGauge_withSDKEnabled_CreatesMetric() {
        // -- Arrange --
        startSDK()
        let sut = SentryMetricsApi()
        
        // -- Act --
        sut.gauge(key: "test.gauge", value: 42.0, unit: "connection")
        flushMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(getMetricDataCount(), 1, "Metric should be created when SDK is enabled")
    }

    func testCount_withZeroValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "button.click"
        let value = 0

        // -- Act --
        sut.count(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testCount_withLargeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "events.processed"
        let value = 1_000_000

        // -- Act --
        sut.count(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testCount_withNegativeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "error.count"
        let value = -1

        // -- Act --
        sut.count(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testCount_withEmptyKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = ""

        // -- Act --
        sut.count(key: key, value: 1)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testCount_withDotDelimitedKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "service.api.endpoint.request.count"

        // -- Act --
        sut.count(key: key, value: 1)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testCount_canBeCalledMultipleTimes_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "event.count"

        // -- Act --
        sut.count(key: key, value: 1)
        sut.count(key: key, value: 2)
        sut.count(key: key, value: 3)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    // MARK: - Tests - Distribution

    func testDistribution_withValidKeyAndValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "http.request.duration"
        let value = 187.5

        // -- Act --
        sut.distribution(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_withZeroValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "response.time"
        let value = 0.0

        // -- Act --
        sut.distribution(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_withLargeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "processing.duration"
        let value = 999_999.99

        // -- Act --
        sut.distribution(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_withNegativeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "latency"
        let value = -10.5

        // -- Act --
        sut.distribution(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_withEmptyKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = ""

        // -- Act --
        sut.distribution(key: key, value: 1.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_withDotDelimitedKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "service.api.endpoint.request.duration"

        // -- Act --
        sut.distribution(key: key, value: 1.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testDistribution_canBeCalledMultipleTimes_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "response.time"

        // -- Act --
        sut.distribution(key: key, value: 100.0)
        sut.distribution(key: key, value: 200.0)
        sut.distribution(key: key, value: 150.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    // MARK: - Tests - Gauge

    func testGauge_withValidKeyAndValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "memory.usage"
        let value = 1_024.0

        // -- Act --
        sut.gauge(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_withZeroValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "queue.depth"
        let value = 0.0

        // -- Act --
        sut.gauge(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_withLargeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "active.connections"
        let value = 50_000.0

        // -- Act --
        sut.gauge(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_withNegativeValue_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "temperature"
        let value = -5.0

        // -- Act --
        sut.gauge(key: key, value: value)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_withEmptyKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = ""

        // -- Act --
        sut.gauge(key: key, value: 1.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_withDotDelimitedKey_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "service.api.endpoint.queue.depth"

        // -- Act --
        sut.gauge(key: key, value: 1.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    func testGauge_canBeCalledMultipleTimes_shouldNotCreateMetric() {
        // -- Arrange --
        let sut = SentryMetricsApi()
        let key = "queue.size"

        // -- Act --
        sut.gauge(key: key, value: 10.0)
        sut.gauge(key: key, value: 20.0)
        sut.gauge(key: key, value: 15.0)
        flushMetrics()

        // -- Assert --
        XCTAssertEqual(getMetricDataCount(), 0, "No metrics should be created when SDK is not started")
    }

    // MARK: - Helpers

    private func startSDK(enableMetrics: Bool = true) {
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryMetricsApiTests.self)
            $0.removeAllIntegrations()
            $0.experimental.enableMetrics = enableMetrics
        }
        SentrySDKInternal.setCurrentHub(hub)
    }

    private func flushMetrics() {
        // We can not rely on SentrySDK.flush() because we are using a test client which is not actually
        // flushing integrations. Calling captureMetrics() on the metrics integration will flush the data
        // synchronously, allowing us to assert the client invocations.
        if let integration = SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration<SentryDependencyContainer> {
            _ = integration.captureMetrics()
        }
    }

    private func getMetricDataCount() -> Int {
        return client.captureMetricsDataInvocations.count
    }

    private func getMetricEnvelopeCount() -> Int {
        let envelopes = client.captureEnvelopeInvocations.invocations
        let metricEnvelopes = envelopes.filter { envelope in
            envelope.items.first?.header.type == SentryEnvelopeItemTypes.traceMetric
        }
        return metricEnvelopes.count
    }

}
