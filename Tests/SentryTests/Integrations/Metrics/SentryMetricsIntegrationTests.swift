import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMetricsIntegrationTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests

    func testStartSDK_whenIntegrationIsNotEnabled_shouldNotBeInstalled() {
        // -- Arrange --
        // SDK not enabled in startSDK call

        // -- Act --
        startSDK(isEnabled: false)

        // -- Assert --
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 0)
    }

    func testStartSDK_whenIntegrationIsEnabled_shouldBeInstalled() {
        // -- Arrange --
        // SDK enabled in startSDK call

        // -- Act --
        startSDK(isEnabled: true)

        // -- Assert --
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().first, "Metrics")
    }

    func testAddMetric_whenMetricAdded_shouldForwardToTelemetryProcessor() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()
        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 1, "Metric should be forwarded to telemetry processor")
        let capturedMetric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(capturedMetric.name, "test.metric")
        XCTAssertEqual(capturedMetric.value, .counter(1))
    }

    func testAddMetric_whenNoClientAvailable_shouldDropMetricsSilently() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let integration = try getSut()

        // Create a new hub without a client to simulate no client scenario
        let hubWithoutClient = SentryHubInternal(
            client: nil,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        let originalHub = SentrySDKInternal.currentHub()
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        defer {
            // Restore original hub for cleanup
            SentrySDKInternal.setCurrentHub(originalHub)
        }

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        // Should not crash and metrics should be dropped silently
        // The integration handles nil client gracefully (verified by no crash)
    }

    // MARK: - BeforeSendMetric Callback Tests

    func testAddMetric_beforeSendMetricModifiesMetric() throws {
        // -- Arrange --
        var beforeSendCalled = false
        let client = try givenSdkWithHub { options in
            options.beforeSendMetric = { metric in
                beforeSendCalled = true

                XCTAssertEqual(metric.name, "test.metric")
                XCTAssertEqual(metric.value, .counter(1))

                var modifiedMetric = metric
                modifiedMetric.attributes["modified_by_callback"] = .string("test_value")
                return modifiedMetric
            }
        }

        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertTrue(beforeSendCalled, "beforeSendMetric should be called")
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 1, "Modified metric should be forwarded to telemetry processor")

        let capturedMetric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(capturedMetric.attributes["modified_by_callback"]?.anyValue as? String, "test_value",
                      "Metric should have modified attribute")
    }

    func testAddMetric_beforeSendMetricReturnsNil_metricDropped() throws {
        // -- Arrange --
        var beforeSendCalled = false
        let client = try givenSdkWithHub { options in
            options.beforeSendMetric = { _ in
                beforeSendCalled = true
                return nil // Drop the metric
            }
        }

        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertTrue(beforeSendCalled, "beforeSendMetric should be called")
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when beforeSendMetric returns nil")
    }

    func testAddMetric_beforeSendMetricNotSet_metricCapturedUnmodified() throws {
        // -- Arrange --
        let client = try givenSdkWithHub { options in
            options.beforeSendMetric = nil
        }

        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 1, "Metric should be forwarded when beforeSendMetric is not set")

        let capturedMetric = try XCTUnwrap(client.testMetricsBuffer.addInvocations.first)
        XCTAssertEqual(capturedMetric.name, "test.metric")
        XCTAssertEqual(capturedMetric.value, .counter(1))
    }

    func testAddMetric_beforeSendMetricCalledAfterScopeIsApplied() throws {
        // -- Arrange --
        var beforeSendCalled = false
        try givenSdkWithHub { options in
            options.environment = "test"
            options.beforeSendMetric = { metric in
                beforeSendCalled = true

                // Verify that scope attributes were already applied before the callback runs
                XCTAssertEqual(metric.attributes["sentry.sdk.name"]?.anyValue as? String, SentryMeta.sdkName,
                              "Scope should be applied BEFORE beforeSendMetric callback")
                XCTAssertEqual(metric.attributes["sentry.environment"]?.anyValue as? String, "test",
                              "Scope should be applied BEFORE beforeSendMetric callback")

                return metric
            }
        }

        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertTrue(beforeSendCalled, "beforeSendMetric should be called")
    }

    func testAddMetric_whenClientDisabled_shouldDropMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub()
        let integration = try getSut()

        client.close()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when client is disabled")
    }

    func testAddMetric_whenSdkDisabledViaOptions_shouldDropMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub { $0.enabled = false }
        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when options.enabled is false")
    }

    func testAddMetric_whenNoDsn_shouldDropMetric() throws {
        // -- Arrange --
        let client = try givenSdkWithHub { $0.parsedDsn = nil }
        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when no DSN is configured")
    }

    func testAddMetric_whenClientDisabled_shouldNotCallBeforeSendMetric() throws {
        // -- Arrange --
        var beforeSendCalled = false
        let client = try givenSdkWithHub { options in
            options.enabled = false
            options.beforeSendMetric = { metric in
                beforeSendCalled = true
                return metric
            }
        }
        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        XCTAssertFalse(beforeSendCalled, "beforeSendMetric should not be called when the SDK is disabled")
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when the SDK is disabled")
    }

    func testAddMetric_whenClientDisabled_shouldLogDebugMessage() throws {
        // -- Arrange --
        let oldOutput = SentrySDKLog.getLogOutput()
        defer { SentrySDKLog.setOutput(oldOutput) }
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        try givenSdkWithHub { $0.enabled = false }
        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        integration.addMetric(metric, scope: scope)

        // -- Assert --
        let logs = logOutput.loggedMessages.joined()
        XCTAssertTrue(logs.contains("SDK disabled or no DSN set."), "Expected a debug log when dropping a metric, but got '\(logs)'")
    }

    func testCaptureMetric_whenClientDisabled_shouldDropMetricAndLogDebugMessage() throws {
        // Calls captureMetric directly, bypassing addMetric's gate, to verify the defensive
        // guard inside captureMetric drops the metric and logs when the SDK is disabled.
        // -- Arrange --
        let oldOutput = SentrySDKLog.getLogOutput()
        defer { SentrySDKLog.setOutput(oldOutput) }
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let client = try givenSdkWithHub { $0.enabled = false }

        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )

        // -- Act --
        client.captureMetric(metric)

        // -- Assert --
        XCTAssertEqual(client.testMetricsBuffer.addInvocations.count, 0, "Metric should be dropped when the SDK is disabled")
        let logs = logOutput.loggedMessages.joined()
        XCTAssertTrue(logs.contains("SDK disabled or no DSN set."), "Expected a debug log when dropping a metric, but got '\(logs)'")
    }

    func testName_shouldReturnCorrectName() {
        // -- Act & Assert --
        XCTAssertEqual(SentryMetricsIntegration<SentryDependencyContainer>.name, "SentryMetricsIntegration")
    }

    // MARK: - Helpers

    private func startSDK(isEnabled: Bool, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: Self.self)
            $0.removeAllIntegrations()

            $0.enableMetrics = isEnabled

            configure?($0)
        }
    }

    @discardableResult
    private func givenSdkWithHub(configure: ((Options) -> Void)? = nil) throws -> MetricsTestClient {
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.removeAllIntegrations()
        options.enableMetrics = true

        configure?(options)

        let client = try XCTUnwrap(MetricsTestClient(options: options))
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )

        SentrySDK.setStart(with: options)
        SentrySDKInternal.setCurrentHub(hub)

        // Manually install the MetricsIntegration since we're not using SentrySDK.start()
        let dependencies = SentryDependencyContainer.sharedInstance()
        let integration = try XCTUnwrap(SentryMetricsIntegration<SentryDependencyContainer>(with: options, dependencies: dependencies) as Any as? SentryIntegrationProtocol)
        hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<SentryDependencyContainer>.name)

        hub.startSession()

        return client
    }

    private func getSut() throws -> SentryMetricsIntegration<SentryDependencyContainer> {
        return try XCTUnwrap(SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration)
    }
}

// MARK: - Test Doubles

/// Test client that overrides `telemetryProcessor` to return a test processor
/// with an observable metrics buffer, allowing tests to verify which metrics were forwarded.
private class MetricsTestClient: TestClient {
    let testMetricsBuffer = TestMetricsTelemetryBuffer()

    private lazy var testProcessor: SentryDefaultTelemetryProcessor = {
        SentryDefaultTelemetryProcessor(
            logBuffer: NoOpLogTelemetryBuffer(),
            metricsBuffer: testMetricsBuffer
        )
    }()

    override func getTelemetryProcessor() -> Any {
        return testProcessor
    }
}

private final class TestMetricsTelemetryBuffer: TelemetryBuffer {
    var addInvocations = Invocations<SentryMetric>()

    func add(_ item: SentryMetric) {
        addInvocations.record(item)
    }

    @discardableResult
    func capture() -> TimeInterval { 0.0 }
}

private final class NoOpLogTelemetryBuffer: TelemetryBuffer {
    func add(_ item: SentryLog) {}
    @discardableResult func capture() -> TimeInterval { 0.0 }
}
