@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryMetricsBatcherTests: XCTestCase {

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testCallbackHelper: TestMetricsBatcherCallbackHelper!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true

        testDateProvider = TestCurrentDateProvider()
        testCallbackHelper = TestMetricsBatcherCallbackHelper()
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

    private func getSut() -> SentryMetricsBatcher {
        return SentryMetricsBatcher(
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
        let metric1 = createTestMetric(name: "metric.one", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.two", value: .counter(2))

        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric1, scope: scope)
        sut.addMetric(metric2, scope: scope)

        // Trigger flush manually
        sut.captureMetrics()

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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
        sut.addMetric(largeMetric, scope: scope)

        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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
            sut.addMetric(metric, scope: scope)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0)
        
        let metric = createTestMetric(name: "metric.10", value: .counter(10)) // Reached 10 max metrics limit
        sut.addMetric(metric, scope: scope)
        
        // -- Assert -- Should have flushed once when reaching maxMetricCount
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1)
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 10, "Should have captured exactly 10 metrics")
    }
    
    // MARK: - Timeout Tests
    
    func testAddMetric_whenTimeoutExpires_shouldFlush() throws {
        // -- Arrange --
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

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
        let metric1 = createTestMetric(name: "metric.1", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.2", value: .counter(2))

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
        let defaultBatcher = SentryMetricsBatcher(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        defaultBatcher.addMetric(metric, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 5.0, "Default flushTimeout should be 5 seconds")
    }
    
    func testInit_whenMaxMetricCountNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new batcher without specifying maxMetricCount to use default (100)
        let defaultBatcher = SentryMetricsBatcher(
            options: options,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            capturedDataCallback: testCallbackHelper.captureCallback
        )
        
        // -- Act -- Add exactly 99 metrics (should not flush)
        for i in 0..<99 {
            let metric = createTestMetric(name: "metric.\(i + 1)", value: .counter(UInt(i + 1)))
            defaultBatcher.addMetric(metric, scope: scope)
        }
        
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 0, "Should not flush before reaching default maxMetricCount")
        
        // Add the 100th metric (should trigger flush)
        let metric100 = createTestMetric(name: "metric.100", value: .counter(100))
        defaultBatcher.addMetric(metric100, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when reaching default maxMetricCount of 100")
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 100, "Should have captured exactly 100 metrics")
    }
    
    func testInit_whenMaxBufferSizeBytesNotProvided_shouldUseDefaultValue() throws {
        // -- Arrange --
        // Create a new batcher without specifying maxBufferSizeBytes to use default (1MB)
        // Note: Individual trace metrics must not exceed 2KB each (Relay's max_trace_metric_size limit),
        // but the buffer can accumulate up to 1MB before flushing.
        let defaultBatcher = SentryMetricsBatcher(
            options: options,
            flushTimeout: 0.1,
            maxMetricCount: 100_000, // High count to avoid count-based flush, focus on size limit
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
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
            defaultBatcher.addMetric(metric, scope: scope)
        }
        
        // -- Assert --
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should flush when exceeding default maxBufferSizeBytes of 1MB")
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
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
    
    func testCaptureMetrics_whenMultipleMetrics_shouldMeasureDuration() throws {
        // -- Arrange --
        let sut = getSut()
        // Add multiple metrics to ensure there's actual work being done
        for i in 0..<5 {
            let metric = createTestMetric(name: "metric.\(i)", value: .counter(UInt(i)))
            sut.addMetric(metric, scope: scope)
        }
        
        // -- Act --
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        // Duration should be measurable (even if small) when metrics are processed
        // We verify that captureMetrics actually measures time by checking it's >= 0
        // The actual duration depends on system performance, so we just verify it's non-negative
        XCTAssertEqual(testCallbackHelper.captureMetricsDataInvocations.count, 1, "Should invoke callback once")
        
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 5, "Should capture all 5 metrics")
    }
    
    // MARK: - Metrics Disabled Tests
    
    func testAddMetric_whenMetricsDisabled_shouldNotAddMetrics() throws {
        // -- Arrange --
        options.experimental.enableMetrics = false

        let metric = createTestMetric(name: "test.metric", value: .counter(1))

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
        let metric1 = createTestMetric(name: "metric.1", value: .counter(1))
        let metric2 = createTestMetric(name: "metric.2", value: .counter(2))

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
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.element(at: 0)?["name"] as? String, "metric.1")
        XCTAssertEqual(capturedMetrics.element(at: 1)?["name"] as? String, "metric.2")

        // Assert no further metrics
        XCTAssertEqual(capturedMetrics.count, 2)
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddMetric_whenDefaultAttributesExist_shouldAddDefaultAttributes() throws {
        // -- Arrange --
        options.environment = "test-environment"
        options.releaseName = "1.0.0"
        
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 1)
        
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        XCTAssertEqual(try XCTUnwrap(attributes["sentry.sdk.name"] as? [String: Any])["value"] as? String, SentryMeta.sdkName)
        XCTAssertEqual(try XCTUnwrap(attributes["sentry.sdk.version"] as? [String: Any])["value"] as? String, SentryMeta.versionString)
        XCTAssertEqual(try XCTUnwrap(attributes["sentry.environment"] as? [String: Any])["value"] as? String, "test-environment")
        XCTAssertEqual(try XCTUnwrap(attributes["sentry.release"] as? [String: Any])["value"] as? String, "1.0.0")
    }
    
    func testAddMetric_whenNilDefaultAttributes_shouldNotAddNilAttributes() throws {
        // -- Arrange --
        options.releaseName = nil

        // No span set on scope
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
        
        // But should still have the non-nil defaults
        XCTAssertEqual(try XCTUnwrap(attributes["sentry.sdk.name"] as? [String: Any])["value"] as? String, SentryMeta.sdkName)
        XCTAssertEqual(try XCTUnwrap(attributes["sentry.sdk.version"] as? [String: Any])["value"] as? String, SentryMeta.versionString)
        XCTAssertNotNil(attributes["sentry.environment"])
    }
    
    func testAddMetric_whenPropagationContextExists_shouldSetTraceIdFromPropagationContext() throws {
        // -- Arrange --
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(traceId: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        XCTAssertEqual(capturedMetric["trace_id"] as? String, expectedTraceId.sentryIdString)
    }
    
    func testAddMetric_whenActiveSpanExists_shouldSetSpanIdFromActiveSpan() throws {
        // -- Arrange --
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(attributes["span_id"] as? [String: Any])["value"] as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddMetric_whenNoActiveSpan_shouldNotSetSpanId() throws {
        // -- Arrange --
        // No span set on scope
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

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
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        let userIdAttr = try XCTUnwrap(attributes["user.id"] as? [String: Any])
        XCTAssertEqual(userIdAttr["value"] as? String, "123")
        let userNameAttr = try XCTUnwrap(attributes["user.name"] as? [String: Any])
        XCTAssertEqual(userNameAttr["value"] as? String, "test-name")
        let userIEmailAttr = try XCTUnwrap(attributes["user.email"] as? [String: Any])
        XCTAssertEqual(userIEmailAttr["value"] as? String, "test@test.com")
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
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        let userIdAttr = try XCTUnwrap(attributes["user.id"] as? [String: Any])
        XCTAssertEqual(userIdAttr["value"] as? String, installationId)
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddMetric_whenScopeAttributesExist_shouldAddScopeAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "scope-key")
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        let scopeKeyAttr = try XCTUnwrap(attributes["scope-key"] as? [String: Any])
        XCTAssertEqual(scopeKeyAttr["value"] as? String, "scope-value")
    }
    
    func testAddMetric_whenScopeAttributesExist_shouldNotOverrideExistingAttributes() throws {
        // -- Arrange --
        scope.setAttribute(value: "scope-value", key: "existing-key")
        
        var metric = createTestMetric(name: "test.metric", value: .counter(1))
        metric.attributes["existing-key"] = .string("metric-value")

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])

        // Metric attribute should take precedence
        let attr = try XCTUnwrap(attributes["existing-key"] as? [String: Any])
        XCTAssertEqual(attr["value"] as? String, "metric-value")
    }
    
    // MARK: - BeforeSendMetric Tests
    
    func testAddMetric_whenBeforeSendMetricModifiesMetric_shouldCaptureModifiedMetric() throws {
        // -- Arrange --
        options.experimental.beforeSendMetric = { metric in
            var modifiedMetric = metric
            modifiedMetric.attributes["test-attr"] = .string("modified")
            return modifiedMetric
        }
        
        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        let duration = sut.captureMetrics()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0, "captureMetrics should return a non-negative duration")
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
        let capturedMetric = try XCTUnwrap(capturedMetrics.first)
        let attributes = try XCTUnwrap(capturedMetric["attributes"] as? [String: Any])
        let testAttr = try XCTUnwrap(attributes["test-attr"] as? [String: Any])
        XCTAssertEqual(testAttr["value"] as? String, "modified")
    }
    
    func testAddMetric_whenBeforeSendMetricReturnsNil_shouldDropMetric() throws {
        // -- Arrange --
        options.experimental.beforeSendMetric = { _ in nil }

        let metric = createTestMetric(name: "test.metric", value: .counter(1))
        
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
        let metric = createTestMetric(
            name: "counter.metric",
            value: .counter(42),
            unit: "connection"
        )

        // -- Act --
        let sut = getSut()
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()

        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()

        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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
        sut.addMetric(metric, scope: scope)
        sut.captureMetrics()
        
        // -- Assert --
        let capturedMetrics = testCallbackHelper.getCapturedMetrics()
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

final class TestMetricsBatcherCallbackHelper {
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
    func getCapturedMetrics() -> [[String: Any]] {
        var allMetrics: [[String: Any]] = []

        for invocation in captureMetricsDataInvocations.invocations {
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
