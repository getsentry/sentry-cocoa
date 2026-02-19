@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class DefaultSentryMetricsTelemetryBufferTests: XCTestCase {

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testCallbackHelper: TestMetricsBufferCallbackHelper!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true

        testDateProvider = TestCurrentDateProvider()
        testCallbackHelper = TestMetricsBufferCallbackHelper()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
        testCallbackHelper = nil
        testDispatchQueue = nil
    }

    private func getSut() -> DefaultSentryMetricsTelemetryBuffer {
        return DefaultSentryMetricsTelemetryBuffer(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxMetricCount: 10, // Maximum 10 metrics per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: NoOpTelemetryBufferDataForwardingTriggers(),
            capturedDataCallback: testCallbackHelper.captureCallback
        )
    }

    // MARK: - Basic Functionality Tests
    
    func testAddMetric_whenMultipleMetrics_shouldBatchTogether() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.one", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.two", value: .counter(2))

        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1)
        sut.addMetric(metric2)

        // Trigger flush manually
        sut.captureMetrics()

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.element(at: 0)?["name"] as? String, "metric.one")
        XCTAssertEqual(capturedMetrics.element(at: 1)?["name"] as? String, "metric.two")

        // Assert no further metrics
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    // MARK: - Buffer Size Tests
    
    func testAddMetric_whenBufferReachesMaxSize_shouldFlushImmediately() throws {
        // -- Arrange --
        // Create a metric with large attributes to exceed buffer size
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        for i in 0..<100 {
            largeAttributes["key\(i)"] = .string(String(repeating: "A", count: 80))
        }
        let largeMetric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric",
            value: .counter(1),
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(largeMetric)

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.element(at: 0)?["name"] as? String, "large.metric")

        // Assert no further metrics
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    // MARK: - Max Metric Count Tests
    
    func testAddMetric_whenMaxMetricCountReached_shouldFlush() throws {
        // -- Act -- Add exactly maxMetricCount metrics
        let sut = getSut()
        for i in 0..<9 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: .counter(UInt(i + 1)))
            sut.addMetric(metric)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        let metric = createTestMetric(name: "metric.10", value: .counter(10)) // Reached 10 max metrics limit
        sut.addMetric(metric)
        
        // -- Assert -- Should have flushed once when reaching maxMetricCount
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 10, "Should have captured exactly 10 metrics")
    }
    
    // MARK: - Timeout Tests
    
    func testAddMetric_whenTimeoutExpires_shouldFlush() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric)

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // Manually trigger the timer to simulate timeout
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify flush occurred
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    func testAddMetric_whenEmptyBuffer_shouldStartTimer() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.2", value: .counter(2))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1)

        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        sut.addMetric(metric2)
        
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        
        // Should not flush immediately
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Default Values Tests
    
    func testInit_whenFlushTimeoutNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new buffer without specifying flushTimeout to use default
        let defaultBuffer = DefaultSentryMetricsTelemetryBuffer(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: NoOpTelemetryBufferDataForwardingTriggers(),
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        defaultBuffer.addMetric(metric)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 5.0, "Default flushTimeout should be 5 seconds")
    }
    
    func testInit_whenMaxMetricCountNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new buffer without specifying maxMetricCount to use default (100)
        let defaultBuffer = DefaultSentryMetricsTelemetryBuffer(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: NoOpTelemetryBufferDataForwardingTriggers(),
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        // -- Act -- Add exactly 99 metrics (should not flush)
        for i in 0..<99 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: .counter(UInt(i + 1)))
            defaultBuffer.addMetric(metric)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0, "Should not flush before reaching default maxMetricCount")
        
        // Add the 100th metric (should trigger flush)
        let metric100 = createTestMetric(name: "metric.100", value: .counter(100))
        defaultBuffer.addMetric(metric100)
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when reaching default maxMetricCount of 100")
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 100, "Should have captured exactly 100 metrics")
    }
    
    func testInit_whenMaxBufferSizeBytesNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new buffer without specifying maxBufferSizeBytes to use default (1MB)
        // Note: Individual trace metrics must not exceed 2KB each (Relay's max_trace_metric_size limit),
        // but the buffer can accumulate up to 1MB before flushing.
        let defaultBuffer = DefaultSentryMetricsTelemetryBuffer(
            options: options,
            flushTimeout: 0.1,
            maxMetricCount: 100_000, // High count to avoid count-based flush, focus on size limit
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: NoOpTelemetryBufferDataForwardingTriggers(),
            capturedDataCallback: testCallbackHelper.captureCallback
        )

        // -- Act --
        // Add metrics until we exceed the 1MB buffer limit (approximately 500+ metrics at ~2KB each)
        // We'll add enough to ensure we exceed the 1MB limit
        for index in 0..<500 {
            var attributes: [String: SentryMetric.Attribute] = [:]
            // Create attributes that make the metric close to 2KB when serialized
            // Each attribute with ~40 bytes of data, ~40 attributes should be close to 2KB
            for i in 0..<40 {
                attributes["key\(i)"] = .string(String(repeating: "A", count: 40))
            }
            let metric = SentryMetric(
                timestamp: Date(),
                traceId: SentryId(),
                name: "large.metric.\(index)",
                value: .counter(UInt(index)),
                unit: nil,
                attributes: attributes
            )
            defaultBuffer.addMetric(metric)
        }
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when exceeding default maxBufferSizeBytes of 1MB")
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertGreaterThan(capturedMetrics.count, 0, "Should have captured at least one metric")
        XCTAssertLessThanOrEqual(capturedMetrics.count, 600, "Should not have captured more metrics than were added")
    }
    
    // MARK: - Manual Capture Metrics Tests
    
    func testCaptureMetrics_whenMetricsExist_shouldCaptureImmediately() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.2", value: .counter(2))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1)
        sut.addMetric(metric2)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    func testCaptureMetrics_whenScheduledCaptureExists_shouldCancelScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        sut.addMetric(metric)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        XCTAssertTrue(timerWorkItem.isCancelled)
    }
    
    func testCaptureMetrics_whenMultipleMetrics_shouldMeasureDuration() throws {
        // -- Arrange --
        let sut = getSut()
        // Add multiple metrics to ensure there's actual work being done
        for i in 0..<5 {
            let metric = createTestMetric(name: "metric.\(i)", value: .counter(UInt(i)))
            sut.addMetric(metric)
        }
        
        // -- Act --
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        // Duration should be measurable (even if small) when metrics are processed
        // We verify that captureMetrics actually measures time by checking it's >= 0
        // The actual duration depends on system performance, so we just verify it's non-negative
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should invoke callback once")
        
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 5, "Should capture all 5 metrics")
    }
    
    // MARK: - Metrics Disabled Tests
    
    func testAddMetric_whenMetricsDisabled_shouldNotAddMetrics() throws {
        // -- Arrange --
        options.experimental.enableMetrics = false

        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric)
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration even when no metrics are captured")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testFlush_whenBufferAlreadyFlushed_shouldDoNothing() throws {
        // -- Arrange --
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        for i in 0..<50 {
            largeAttributes["key\(i)"] = .string(String(repeating: "B", count: 100))
        }
        let metric1 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric.1",
            value: .counter(1),
            unit: nil,
            attributes: largeAttributes
        )
        let metric2 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric.2",
            value: .counter(2),
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        sut.addMetric(metric2)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
    }
    
    func testAddMetric_whenAfterFlush_shouldStartNewBatch() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.2", value: .counter(2))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1)
        let duration1 = sut.captureMetrics()
        
        XCTAssertGreaterThanOrEqual(duration1, 0)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        sut.addMetric(metric2)
        let duration2 = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration2, 0)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 2)
        
        // Verify each flush contains only one metric
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.element(at: 0)?["name"] as? String, "metric.1")
        XCTAssertEqual(capturedMetrics.element(at: 1)?["name"] as? String, "metric.2")

        // Assert no further metrics
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    // MARK: - Metric Type Tests
    
    func testAddMetric_whenCounterType_shouldCaptureCounter() throws {
        // -- Arrange --
        let metric = createTestMetric(
            name: "counter.metric",
            value: .counter(42),
            unit: "connection"
        )

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric)
        sut.captureMetrics()

        // -- Assert --
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric["type"] as? String, "counter")
        XCTAssertEqual(capturedMetric["value"] as? Int64, 42)
        XCTAssertEqual(capturedMetric["unit"] as? String, "connection")

        // Assert no additional metrics
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    func testAddMetric_whenDistributionType_shouldCaptureDistribution() throws {
        // -- Arrange --
        let metric = createTestMetric(
            name: "distribution.metric",
            value: .distribution(42.123456),
            unit: "percent"
        )

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric)
        sut.captureMetrics()

        // -- Assert --
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric["type"] as? String, "distribution")
        XCTAssertEqual(capturedMetric["value"] as? Double, 42.123456)
        XCTAssertEqual(capturedMetric["unit"] as? String, "percent")

        // Assert no additional metrics
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    func testAddMetric_whenGaugeType_shouldCaptureGauge() throws {
        // -- Arrange --
        let metric = createTestMetric(
            name: "gauge.metric",
            value: .gauge(42.0),
            unit: "connection"
        )

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = try testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric["type"] as? String, "gauge")
        XCTAssertEqual(capturedMetric["value"] as? Double, 42.0)
        XCTAssertEqual(capturedMetric["unit"] as? String, "connection")

        // Assert no additional metrics
        XCTAssertEqual(capturedMetrics.count, 1)
    }

    // MARK: - Helper Methods

    private func createTestMetric(name: String, value: SentryMetric.Value, unit: String? = nil, attributes: [String: SentryMetric.Attribute] = [:]) -> SentryMetric {
        let metricsUnit: SentryUnit? = unit.map { .generic($0) }
        return SentryMetric(
            timestamp: Date(),
            traceId: SentryId.empty,
            name: name,
            value: value,
            unit: metricsUnit,
            attributes: attributes
        )
    }
}

// MARK: - Test Callback Helper

final class TestMetricsBufferCallbackHelper {
    var captureMetricsDataInvocations = Invocations<(data: Data, count: Int)>()
    
    // The callback that matches the MetricsBuffer capturedDataCallback signature
    var captureCallback: (Data, Int) -> Void {
        return { [weak self] data, count in
            self?.captureMetricsDataInvocations.record((data, count))
        }
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
    func getCapturedMetrics() throws -> [[String: Any]] {
        var allMetrics: [[String: Any]] = []

        for invocation in captureMetricsDataInvocations.invocations {
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: invocation.data) as? [String: Any])
            if let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    allMetrics.append(item)
                }
            }
        }

        return allMetrics
    }
}
