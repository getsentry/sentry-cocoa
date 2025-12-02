@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testDelegate: TestMetricBatcherDelegate!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var sut: SentryMetricBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryMetricBatcherTests")
        options.enableMetrics = true
        
        testDelegate = TestMetricBatcherDelegate()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
        
        sut = SentryMetricBatcher(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxMetricCount: 10, // Maximum 10 metrics per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing
            dispatchQueue: testDispatchQueue,
            delegate: testDelegate
        )
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
        testDelegate = nil
        testDispatchQueue = nil
        sut = nil
        scope = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddMultipleMetrics_BatchesTogether() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.one", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.two", value: 2, type: .counter)
        
        // -- Act --
        sut.addMetric(metric1, scope: scope)
        sut.addMetric(metric2, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
        
        // Trigger flush manually
        sut.captureMetrics()
        
        // Verify both metrics are batched together
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 2)
        XCTAssertEqual(capturedMetrics[0].name, "metric.one")
        XCTAssertEqual(capturedMetrics[1].name, "metric.two")
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // -- Arrange --
        // Create a metric with large attributes to exceed buffer size
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        for i in 0..<100 {
            largeAttributes["key\(i)"] = .init(string: String(repeating: "A", count: 80))
        }
        let largeMetric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            spanId: nil,
            name: "large.metric",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        sut.addMetric(largeMetric, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        XCTAssertEqual(capturedMetrics[0].name, "large.metric")
    }
    
    // MARK: - Max Metric Count Tests
    
    func testMaxMetricCount_FlushesWhenReached() throws {
        // -- Act -- Add exactly maxMetricCount metrics
        for i in 0..<9 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: Double(i + 1), type: .counter)
            sut.addMetric(metric, scope: scope)
        }
        
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
        
        let metric = createTestMetric(name: "metric.10", value: 10, type: .counter) // Reached 10 max metrics limit
        sut.addMetric(metric, scope: scope)
        
        // -- Assert -- Should have flushed once when reaching maxMetricCount
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 10, "Should have captured exactly 10 metrics")
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // Manually trigger the timer to simulate timeout
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify flush occurred
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    func testAddingMetricToEmptyBuffer_StartsTimer() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        sut.addMetric(metric1, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        sut.addMetric(metric2, scope: scope)
        
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        
        // Should not flush immediately
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Manual Capture Metrics Tests
    
    func testManualCaptureMetrics_CapturesImmediately() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        sut.addMetric(metric1, scope: scope)
        sut.addMetric(metric2, scope: scope)
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
        
        sut.captureMetrics()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    func testManualCaptureMetrics_CancelsScheduledCapture() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        sut.addMetric(metric, scope: scope)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        sut.captureMetrics()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        XCTAssertTrue(timerWorkItem.isCancelled)
    }
    
    // MARK: - Metrics Disabled Tests
    
    func testMetricsDisabled_DoesNotAddMetrics() throws {
        // -- Arrange --
        options.enableMetrics = false
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // -- Arrange --
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        for i in 0..<50 {
            largeAttributes["key\(i)"] = .init(string: String(repeating: "B", count: 100))
        }
        let metric1 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            spanId: nil,
            name: "large.metric.1",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        let metric2 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            spanId: nil,
            name: "large.metric.2",
            value: NSNumber(value: 2),
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        sut.addMetric(metric1, scope: scope)
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        sut.addMetric(metric2, scope: scope)
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
    }
    
    func testAddMetricAfterFlush_StartsNewBatch() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        sut.addMetric(metric1, scope: scope)
        sut.captureMetrics()
        
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 1)
        
        sut.addMetric(metric2, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 2)
        
        // Verify each flush contains only one metric
        let allCapturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(allCapturedMetrics.count, 2)
        XCTAssertEqual(allCapturedMetrics[0].name, "metric.1")
        XCTAssertEqual(allCapturedMetrics[1].name, "metric.2")
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddMetric_AddsDefaultAttributes() throws {
        // -- Arrange --
        options.environment = "test-environment"
        options.releaseName = "1.0.0"
        
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddMetric_DoesNotAddNilDefaultAttributes() throws {
        // -- Arrange --
        options.releaseName = nil
        // No span set on scope
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
        
        // But should still have the non-nil defaults
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertNotNil(attributes["sentry.environment"])
    }
    
    func testAddMetric_SetsTraceIdFromPropagationContext() throws {
        // -- Arrange --
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(trace: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.traceId, expectedTraceId)
    }
    
    func testAddMetric_SetsSpanIdFromActiveSpan() throws {
        // -- Arrange --
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.spanId, span.spanId)
    }
    
    func testAddMetric_DoesNotSetSpanIdWhenNoActiveSpan() throws {
        // -- Arrange --
        // No span set on scope
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertNil(capturedMetric.spanId)
    }
    
    func testAddMetric_AddsUserAttributes() throws {
        // -- Arrange --
        options.sendDefaultPii = true
        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(attributes["user.email"]?.value as? String, "test@test.com")
    }
    
    func testAddMetric_DoesNotAddUserAttributesWhenSendDefaultPiiFalse() throws {
        // -- Arrange --
        options.sendDefaultPii = false
        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertNil(attributes["user.id"])
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddMetric_AddsScopeAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "scope-key")
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["scope-key"]?.value as? String, "scope-value")
    }
    
    func testAddMetric_ScopeAttributesDoNotOverrideExistingAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "existing-key")
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        metric.setAttribute(.init(string: "metric-value"), forKey: "existing-key")
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        // Metric attribute should take precedence
        XCTAssertEqual(attributes["existing-key"]?.value as? String, "metric-value")
    }
    
    // MARK: - BeforeSendMetric Tests
    
    func testBeforeSendMetric_ModifiesMetric() throws {
        // -- Arrange --
        options.beforeSendMetric = { metric in
            var modifiedMetric = metric
            modifiedMetric.setAttribute(.init(string: "modified"), forKey: "test-attr")
            return modifiedMetric
        }
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.attributes["test-attr"]?.value as? String, "modified")
    }
    
    func testBeforeSendMetric_ReturnsNil_DropsMetric() throws {
        // -- Arrange --
        options.beforeSendMetric = { _ in nil }
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Metric Type Tests
    
    func testAddMetric_Counter() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "counter.metric", value: 5, type: .counter)
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.type, .counter)
        XCTAssertEqual(capturedMetric.value.intValue, 5)
    }
    
    func testAddMetric_Distribution() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "distribution.metric", value: 125.5, type: .distribution, unit: "millisecond")
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.type, .distribution)
        XCTAssertEqual(capturedMetric.value.doubleValue, 125.5, accuracy: 0.001)
        XCTAssertEqual(capturedMetric.unit, "millisecond")
    }
    
    func testAddMetric_Gauge() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "gauge.metric", value: 42.0, type: .gauge, unit: "connection")
        
        // -- Act --
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testDelegate.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.type, .gauge)
        XCTAssertEqual(capturedMetric.value.doubleValue, 42.0, accuracy: 0.001)
        XCTAssertEqual(capturedMetric.unit, "connection")
    }
    
    // MARK: - Helper Methods
    
    private func createTestMetric(name: String, value: Double, type: MetricType, unit: String? = nil, attributes: [String: SentryMetric.Attribute] = [:]) -> SentryMetric {
        return SentryMetric(
            timestamp: Date(),
            traceId: SentryId.empty,
            spanId: nil,
            name: name,
            value: NSNumber(value: value),
            type: type,
            unit: unit,
            attributes: attributes
        )
    }
}

// MARK: - Test Delegate

final class TestMetricBatcherDelegate: NSObject, SentryMetricBatcherDelegate {
    var captureMetricsDataInvocations = Invocations<(data: Data, count: NSNumber)>()
    
    func capture(metricsData: NSData, count: NSNumber) {
        captureMetricsDataInvocations.record((metricsData as Data, count))
    }
    
    // Helper to get captured metrics
    func getCapturedMetrics() -> [SentryMetric] {
        var allMetrics: [SentryMetric] = []
        
        for invocation in captureMetricsDataInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let metric = parseSentryMetric(from: item) {
                        allMetrics.append(metric)
                    }
                }
            }
        }
        
        return allMetrics
    }
    
    private func parseSentryMetric(from dict: [String: Any]) -> SentryMetric? {
        guard let name = dict["name"] as? String,
              let typeString = dict["type"] as? String,
              let type = parseMetricType(typeString) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: (dict["timestamp"] as? TimeInterval) ?? 0)
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)
        
        let spanIdString = dict["span_id"] as? String
        let spanId = spanIdString.map { SentrySpanId(value: $0) }
        
        let value: NSNumber
        if let intValue = dict["value"] as? Int64 {
            value = NSNumber(value: intValue)
        } else if let doubleValue = dict["value"] as? Double {
            value = NSNumber(value: doubleValue)
        } else {
            return nil
        }
        
        let unit = dict["unit"] as? String
        
        var attributes: [String: SentryMetric.Attribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, value) in attributesDict {
                if let attrValue = value["value"] {
                    attributes[key] = SentryMetric.Attribute(value: attrValue)
                }
            }
        }
        
        return SentryMetric(
            timestamp: timestamp,
            traceId: traceId,
            spanId: spanId,
            name: name,
            value: value,
            type: type,
            unit: unit,
            attributes: attributes
        )
    }
    
    private func parseMetricType(_ string: String) -> MetricType? {
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
