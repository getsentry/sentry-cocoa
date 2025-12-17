@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricBatcherTests: XCTestCase {

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testCallbackHelper: TestMetricBatcherCallbackHelper!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true

        testDateProvider = TestCurrentDateProvider()
        testCallbackHelper = TestMetricBatcherCallbackHelper()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately

        scope = Scope()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
        testCallbackHelper = nil
        testDispatchQueue = nil
        scope = nil
    }

    private func getSut() -> SentryMetricBatcher {
        return SentryMetricBatcher(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxMetricCount: 10, // Maximum 10 metrics per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
    }

    // MARK: - Basic Functionality Tests
    
    func testAddMetric_whenMultipleMetrics_shouldBatchTogether() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.one", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.two", value: 2, type: .counter)

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)
        sut.addMetric(metric2, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        // Trigger flush manually
        sut.captureMetrics()
        
        // Verify both metrics are batched together
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 2)
        XCTAssertEqual(capturedMetrics[0].name, "metric.one")
        XCTAssertEqual(capturedMetrics[1].name, "metric.two")
    }
    
    // MARK: - Buffer Size Tests
    
    func testAddMetric_whenBufferReachesMaxSize_shouldFlushImmediately() throws {
        // -- Arrange --
        // Create a metric with large attributes to exceed buffer size
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        for i in 0..<100 {
            largeAttributes["key\(i)"] = .init(string: String(repeating: "A", count: 80))
        }
        let largeMetric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric",
            value: 1,
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(largeMetric, scope: scope)

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        XCTAssertEqual(capturedMetrics[0].name, "large.metric")
    }
    
    // MARK: - Max Metric Count Tests
    
    func testAddMetric_whenMaxMetricCountReached_shouldFlush() throws {
        // -- Act -- Add exactly maxMetricCount metrics
        let sut = getSut()
        for i in 0..<9 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: Double(i + 1), type: .counter)
            sut.addMetric(metric, scope: scope)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        let metric = createTestMetric(name: "metric.10", value: 10, type: .counter) // Reached 10 max metrics limit
        sut.addMetric(metric, scope: scope)
        
        // -- Assert -- Should have flushed once when reaching maxMetricCount
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 10, "Should have captured exactly 10 metrics")
    }
    
    // MARK: - Timeout Tests
    
    func testAddMetric_whenTimeoutExpires_shouldFlush() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // Manually trigger the timer to simulate timeout
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify flush occurred
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
    }
    
    func testAddMetric_whenEmptyBuffer_shouldStartTimer() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)

        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        sut.addMetric(metric2, scope: scope)
        
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        
        // Should not flush immediately
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Default Values Tests
    
    func testInit_whenFlushTimeoutNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new batcher without specifying flushTimeout to use default
        let defaultBatcher = SentryMetricBatcher(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        defaultBatcher.addMetric(metric, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 5.0, "Default flushTimeout should be 5 seconds")
    }
    
    func testInit_whenMaxMetricCountNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new batcher without specifying maxMetricCount to use default (100)
        let defaultBatcher = SentryMetricBatcher(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        // -- Act -- Add exactly 99 metrics (should not flush)
        for i in 0..<99 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: Double(i + 1), type: .counter)
            defaultBatcher.addMetric(metric, scope: scope)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0, "Should not flush before reaching default maxMetricCount")
        
        // Add the 100th metric (should trigger flush)
        let metric100 = createTestMetric(name: "metric.100", value: 100, type: .counter)
        defaultBatcher.addMetric(metric100, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when reaching default maxMetricCount of 100")
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 100, "Should have captured exactly 100 metrics")
    }
    
    func testInit_whenMaxBufferSizeBytesNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new batcher without specifying maxBufferSizeBytes to use default (2048 bytes / 2KiB)
        let defaultBatcher = SentryMetricBatcher(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        // Create a metric with large attributes that exceeds the default buffer size of 2048 bytes
        // Each attribute key-value pair adds significant size, so we'll create enough to exceed 2048 bytes
        var largeAttributes: [String: SentryMetric.Attribute] = [:]
        // Create attributes that will exceed 2048 bytes when serialized
        // Each attribute with ~50 bytes of data, so ~40 attributes should exceed 2048 bytes
        for i in 0..<50 {
            largeAttributes["key\(i)"] = .init(string: String(repeating: "A", count: 50))
        }
        
        let largeMetric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric",
            value: 1,
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        defaultBatcher.addMetric(largeMetric, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when exceeding default maxBufferSizeBytes of 2048 bytes")
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        XCTAssertEqual(capturedMetrics[0].name, "large.metric")
    }
    
    // MARK: - Manual Capture Metrics Tests
    
    func testCaptureMetrics_whenMetricsExist_shouldCaptureImmediately() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)
        sut.addMetric(metric2, scope: scope)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    func testCaptureMetrics_whenScheduledCaptureExists_shouldCancelScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        sut.addMetric(metric, scope: scope)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        XCTAssertTrue(timerWorkItem.isCancelled)
    }
    
    // MARK: - Metrics Disabled Tests
    
    func testAddMetric_whenMetricsDisabled_shouldNotAddMetrics() throws {
        // -- Arrange --
        options.experimental.enableMetrics = false

        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
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
            largeAttributes["key\(i)"] = .init(string: String(repeating: "B", count: 100))
        }
        let metric1 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric.1",
            value: 1,
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        let metric2 = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "large.metric.2",
            value: 2,
            type: .counter,
            unit: nil,
            attributes: largeAttributes
        )
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        sut.addMetric(metric2, scope: scope)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
    }
    
    func testAddMetric_whenAfterFlush_shouldStartNewBatch() throws {
        // -- Arrange --
        let metric1 = createTestMetric(name: "metric.1", value: 1, type: .counter)
        let metric2 = createTestMetric(name: "metric.2", value: 2, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)
        let duration1 = sut.captureMetrics()
        
        XCTAssertGreaterThanOrEqual(duration1, 0)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        sut.addMetric(metric2, scope: scope)
        let duration2 = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration2, 0)
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 2)
        
        // Verify each flush contains only one metric
        let allCapturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(allCapturedMetrics.count, 2)
        XCTAssertEqual(allCapturedMetrics[0].name, "metric.1")
        XCTAssertEqual(allCapturedMetrics[1].name, "metric.2")
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddMetric_whenDefaultAttributesExist_shouldAddDefaultAttributes() throws {
        // -- Arrange --
        options.environment = "test-environment"
        options.releaseName = "1.0.0"
        
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(attributes["sentry.release"]?.value as? String, "1.0.0")
    }
    
    func testAddMetric_whenNilDefaultAttributes_shouldNotAddNilAttributes() throws {
        // -- Arrange --
        options.releaseName = nil

        // No span set on scope
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
        
        // But should still have the non-nil defaults
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertNotNil(attributes["sentry.environment"])
    }
    
    func testAddMetric_whenPropagationContextExists_shouldSetTraceIdFromPropagationContext() throws {
        // -- Arrange --
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(trace: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.traceId, expectedTraceId)
    }
    
    func testAddMetric_whenActiveSpanExists_shouldSetSpanIdFromActiveSpan() throws {
        // -- Arrange --
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        XCTAssertEqual(attributes["span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddMetric_whenNoActiveSpan_shouldNotSetSpanId() throws {
        // -- Arrange --
        // No span set on scope
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        XCTAssertNil(attributes["span_id"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
    }
    
    func testAddMetric_whenUserAttributesExist_shouldAddUserAttributes() throws {
        // -- Arrange --
        options.sendDefaultPii = true

        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(attributes["user.email"]?.value as? String, "test@test.com")
    }
    
    func testAddMetric_whenSendDefaultPiiFalse_shouldNotAddUserAttributes() throws {
        // -- Arrange --
        let installationId = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
        options.sendDefaultPii = false

        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, installationId)
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddMetric_whenScopeAttributesExist_shouldAddScopeAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "scope-key")
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        XCTAssertEqual(attributes["scope-key"]?.value as? String, "scope-value")
    }
    
    func testAddMetric_whenScopeAttributesExist_shouldNotOverrideExistingAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "existing-key")
        
        var metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        metric.setAttribute(.init(string: "metric-value"), forKey: "existing-key")
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = capturedMetric.attributes
        
        // Metric attribute should take precedence
        XCTAssertEqual(attributes["existing-key"]?.value as? String, "metric-value")
    }
    
    // MARK: - BeforeSendMetric Tests
    
    func testAddMetric_whenBeforeSendMetricModifiesMetric_shouldCaptureModifiedMetric() throws {
        // -- Arrange --
        options.beforeSendMetric = { metric in
            var modifiedMetric = metric
            modifiedMetric.setAttribute(.init(string: "modified"), forKey: "test-attr")
            return modifiedMetric
        }
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.attributes["test-attr"]?.value as? String, "modified")
    }
    
    func testAddMetric_whenBeforeSendMetricReturnsNil_shouldDropMetric() throws {
        // -- Arrange --
        options.beforeSendMetric = { _ in nil }
        
        let metric = createTestMetric(name: "test.metric", value: 1, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration even when metric is dropped")
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
    }
    
    // MARK: - Metric Type Tests
    
    func testAddMetric_whenCounterType_shouldCaptureCounter() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "counter.metric", value: 5, type: .counter)
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.metricType, .counter)
        XCTAssertEqual(capturedMetric.value, 5)
    }
    
    func testAddMetric_whenDistributionType_shouldCaptureDistribution() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "distribution.metric", value: 125.5, type: .distribution, unit: "millisecond")
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.metricType, .distribution)
        XCTAssertEqual(capturedMetric.value, .double(125.5))
        XCTAssertEqual(capturedMetric.unit, "millisecond")
    }
    
    func testAddMetric_whenGaugeType_shouldCaptureGauge() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "gauge.metric", value: 42.0, type: .gauge, unit: "connection")
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric.metricType, .gauge)
        XCTAssertEqual(capturedMetric.value, 42.0)
        XCTAssertEqual(capturedMetric.unit, "connection")
    }
    
    // MARK: - Helper Methods
    
    private func createTestMetric(name: String, value: Double, type: SentryMetricType, unit: String? = nil, attributes: [String: SentryMetric.Attribute] = [:]) -> SentryMetric {
        return SentryMetric(
            timestamp: Date(),
            traceId: SentryId.empty,
            name: name,
            value: .init(floatLiteral: value),
            type: type,
            unit: unit,
            attributes: attributes
        )
    }
}

// MARK: - Test Callback Helper

final class TestMetricBatcherCallbackHelper {
    var captureMetricsDataInvocations = Invocations<(data: Data, count: Int)>()
    
    // The callback that matches the MetricBatcher capturedDataCallback signature
    var captureCallback: (Data, Int) -> Void {
        return { [weak self] data, count in
            self?.captureMetricsDataInvocations.record((data, count))
        }
    }
    
    // Helper to get captured metrics
    // Note: The batcher produces JSON in the format {"items":[...]} as verified by InMemoryBatchBuffer.batchedData
    //
    // Design decision: We use JSONSerialization instead of:
    // 1. Decodable: Would introduce decoding logic in tests that could be wrong, creating a risk that tests pass
    //    even when the actual encoding/decoding logic is broken.
    // 2. Direct string comparison: JSON key ordering is not guaranteed, so tests would be flaky.
    //
    // JSONSerialization provides a good middle ground: it parses the JSON structure without duplicating
    // the encoding/decoding logic, and it's order-agnostic, making tests stable while still verifying
    // the actual data structure produced by the batcher.
    func getCapturedMetrics() -> [SentryMetric] {
        var allMetrics: [SentryMetric] = []
        
        for invocation in captureMetricsDataInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let metric = parseMetric(from: item) {
                        allMetrics.append(metric)
                    }
                }
            }
        }
        
        return allMetrics
    }
    
    private func parseMetric(from dict: [String: Any]) -> SentryMetric? {
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
            for (key, value) in attributesDict {
                if let attrValue = value["value"] {
                    attributes[key] = SentryMetric.Attribute(value: attrValue)
                }
            }
        }
        
        return SentryMetric(
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
