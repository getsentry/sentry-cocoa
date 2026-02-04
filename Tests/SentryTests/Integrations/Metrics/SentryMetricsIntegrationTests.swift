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
    
    func testAddMetric_whenMetricAdded_shouldAddToBuffer() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")

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

        // We can not rely on the SentrySDK.flush(), because we are using a test client which is not actually
        // flushing integrations as of Dec 16, 2025.
        //
        // Calling uninstall will flush the data, allowing us to assert the client invocations
        integration.uninstall()

        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first)
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")

        // Assert no further invocations
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 1, "Metrics should be captured")
    }
    
    func testUninstall_whenMetricsExist_shouldFlushMetrics() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")

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
        
        integration.addMetric(metric, scope: scope)
        
        // -- Act --
        integration.uninstall()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first)
        XCTAssertEqual(capturedMetrics.count.intValue, 1, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")

        // Assert no further invocations
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 1, "Uninstall should flush metrics")
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
        integration.uninstall()
        
        // -- Assert --
        // Should not crash and metrics should be dropped silently
        // The callback should handle nil client gracefully (verified by no crash)
    }

    // MARK: - BeforeSendMetric Callback Tests

    func testAddMetric_beforeSendMetricModifiesMetric() throws {
        // -- Arrange --
        let testBuffer = TestMetricsTelemetryBuffer()
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true

        var beforeSendCalled = false
        options.experimental.beforeSendMetric = { metric in
            beforeSendCalled = true

            XCTAssertEqual(metric.name, "test.metric")
            XCTAssertEqual(metric.value, .counter(1))

            var modifiedMetric = metric
            modifiedMetric.attributes["modified_by_callback"] = .string("test_value")
            return modifiedMetric
        }

        let dependencies = SentryDependencyContainer.sharedInstance()
        let integration = try XCTUnwrap(
            SentryMetricsIntegration<SentryDependencyContainer>(
                with: options,
                dependencies: dependencies,
                metricsBuffer: testBuffer
            )
        )

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
        XCTAssertEqual(testBuffer.addMetricInvocations.count, 1, "Modified metric should be added to buffer")

        let capturedMetric = try XCTUnwrap(testBuffer.addMetricInvocations.first)
        XCTAssertEqual(capturedMetric.attributes["modified_by_callback"]?.anyValue as? String, "test_value",
                      "Metric should have modified attribute")
    }

    func testAddMetric_beforeSendMetricReturnsNil_metricDropped() throws {
        // -- Arrange --
        let testBuffer = TestMetricsTelemetryBuffer()
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true

        var beforeSendCalled = false
        options.experimental.beforeSendMetric = { _ in
            beforeSendCalled = true
            return nil // Drop the metric
        }

        let dependencies = SentryDependencyContainer.sharedInstance()
        let integration = try XCTUnwrap(
            SentryMetricsIntegration<SentryDependencyContainer>(
                with: options,
                dependencies: dependencies,
                metricsBuffer: testBuffer
            )
        )

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
        XCTAssertEqual(testBuffer.addMetricInvocations.count, 0, "Metric should be dropped when beforeSendMetric returns nil")
    }

    func testAddMetric_beforeSendMetricNotSet_metricCapturedUnmodified() throws {
        // -- Arrange --
        let testBuffer = TestMetricsTelemetryBuffer()
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true
        options.experimental.beforeSendMetric = nil

        let dependencies = SentryDependencyContainer.sharedInstance()
        let integration = try XCTUnwrap(
            SentryMetricsIntegration<SentryDependencyContainer>(
                with: options,
                dependencies: dependencies,
                metricsBuffer: testBuffer
            )
        )

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
        XCTAssertEqual(testBuffer.addMetricInvocations.count, 1, "Metric should be added to buffer when beforeSendMetric is not set")

        let capturedMetric = try XCTUnwrap(testBuffer.addMetricInvocations.first)
        XCTAssertEqual(capturedMetric.name, "test.metric")
        XCTAssertEqual(capturedMetric.value, .counter(1))
    }

    func testAddMetric_beforeSendMetricCalledAfterScopeIsApplied() throws {
        // -- Arrange --
        let testBuffer = TestMetricsTelemetryBuffer()
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true
        options.environment = "test"

        var beforeSendCalled = false
        options.experimental.beforeSendMetric = { metric in
            beforeSendCalled = true

            // Verify that scope attributes were already applied before the callback runs
            XCTAssertEqual(metric.attributes["sentry.sdk.name"]?.anyValue as? String, SentryMeta.sdkName,
                          "Scope should be applied BEFORE beforeSendMetric callback")
            XCTAssertEqual(metric.attributes["sentry.environment"]?.anyValue as? String, "test",
                          "Scope should be applied BEFORE beforeSendMetric callback")

            return metric
        }

        let dependencies = SentryDependencyContainer.sharedInstance()
        let integration = try XCTUnwrap(
            SentryMetricsIntegration<SentryDependencyContainer>(
                with: options,
                dependencies: dependencies,
                metricsBuffer: testBuffer
            )
        )

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
        XCTAssertEqual(testBuffer.addMetricInvocations.count, 1, "Metric should be added to buffer")
    }

    func testName_shouldReturnCorrectName() {
        // -- Act & Assert --
        XCTAssertEqual(SentryMetricsIntegration<SentryDependencyContainer>.name, "SentryMetricsIntegration")
    }
    
    func testFlushableIntegrationConformance() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let integration = try getSut()
        
        // -- Act & Assert --
        let duration = integration.flush()
        XCTAssertGreaterThanOrEqual(duration, 0, "flush() should return non-negative duration")
    }
    
    func testWillResignActive_whenClientAvailable_shouldFlushMetrics() throws {
        #if !(((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK) || os(macOS))
        throw XCTSkip("Not supported on this platform")
        #else
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true
        
        let client = TestClient(options: options)!
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        SentrySDKInternal.setCurrentHub(hub)
        defer {
            SentrySDKInternal.setCurrentHub(nil)
        }
        
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        struct TestDependencies: DateProviderProvider, DispatchQueueWrapperProvider, NotificationCenterProvider {
            let dateProvider: SentryCurrentDateProvider
            let dispatchQueueWrapper: SentryDispatchQueueWrapper
            let notificationCenterWrapper: SentryNSNotificationCenterWrapper
        }
        
        let testDependencies = TestDependencies(
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            notificationCenterWrapper: notificationCenterWrapper
        )
        
        let integration = try XCTUnwrap(SentryMetricsIntegration<TestDependencies>(with: options, dependencies: testDependencies) as Any as? SentryIntegrationProtocol)
        hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<TestDependencies>.name)
        
        let metricsIntegration = try XCTUnwrap(integration as Any as? SentryMetricsIntegration<TestDependencies>)
        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )
        metricsIntegration.addMetric(metric, scope: scope)
        
        // Clear any previous invocations
        client.captureMetricsDataInvocations.removeAll()

        // -- Act --
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        notificationCenterWrapper.post(Notification(name: UIApplication.willResignActiveNotification))
        #elseif os(macOS)
        notificationCenterWrapper.post(Notification(name: NSApplication.willResignActiveNotification))
        #endif
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 1, "Metrics should be flushed on willResignActive")
        #endif
    }
    
    func testWillTerminate_whenClientAvailable_shouldFlushMetrics() throws {
        #if !(((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK) || os(macOS))
        throw XCTSkip("Not supported on this platform")
        #else
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true
        
        let client = TestClient(options: options)!
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        SentrySDKInternal.setCurrentHub(hub)
        defer {
            SentrySDKInternal.setCurrentHub(nil)
        }
        
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        struct TestDependencies: DateProviderProvider, DispatchQueueWrapperProvider, NotificationCenterProvider {
            let dateProvider: SentryCurrentDateProvider
            let dispatchQueueWrapper: SentryDispatchQueueWrapper
            let notificationCenterWrapper: SentryNSNotificationCenterWrapper
        }
        
        let testDependencies = TestDependencies(
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            notificationCenterWrapper: notificationCenterWrapper
        )
        
        let integration = try XCTUnwrap(SentryMetricsIntegration<TestDependencies>(with: options, dependencies: testDependencies) as Any as? SentryIntegrationProtocol)
        hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<TestDependencies>.name)
        
        let metricsIntegration = try XCTUnwrap(integration as Any as? SentryMetricsIntegration<TestDependencies>)
        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: .counter(1),
            unit: nil,
            attributes: [:]
        )
        metricsIntegration.addMetric(metric, scope: scope)
        
        // Clear any previous invocations
        client.captureMetricsDataInvocations.removeAll()
        
        // -- Act --
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        notificationCenterWrapper.post(Notification(name: UIApplication.willTerminateNotification))
        #elseif os(macOS)
        notificationCenterWrapper.post(Notification(name: NSApplication.willTerminateNotification))
        #endif
        
        // -- Assert --
        XCTAssertEqual(client.captureMetricsDataInvocations.count, 1, "Metrics should be flushed on willTerminate")
        #endif
    }
    
    func testWillResignActive_whenNoClient_shouldNotCrash() throws {
        #if !(((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK) || os(macOS))
        throw XCTSkip("Not supported on this platform")
        #else
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.enableMetrics = true
        
        let hubWithoutClient = SentryHubInternal(
            client: nil,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        defer {
            SentrySDKInternal.setCurrentHub(nil)
        }
        
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        struct TestDependencies: DateProviderProvider, DispatchQueueWrapperProvider, NotificationCenterProvider {
            let dateProvider: SentryCurrentDateProvider
            let dispatchQueueWrapper: SentryDispatchQueueWrapper
            let notificationCenterWrapper: SentryNSNotificationCenterWrapper
        }
        
        let testDependencies = TestDependencies(
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            notificationCenterWrapper: notificationCenterWrapper
        )
        
        let integration = try XCTUnwrap(SentryMetricsIntegration<TestDependencies>(with: options, dependencies: testDependencies) as Any as? SentryIntegrationProtocol)
        hubWithoutClient.addInstalledIntegration(integration, name: SentryMetricsIntegration<TestDependencies>.name)
        
        // -- Act & Assert --
        // Should not crash when no client is available
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        notificationCenterWrapper.post(Notification(name: UIApplication.willResignActiveNotification))
        #elseif os(macOS)
        notificationCenterWrapper.post(Notification(name: NSApplication.willResignActiveNotification))
        #endif
        
        XCTAssertTrue(true, "Should handle missing client gracefully")
        #endif
    }

    // MARK: - Helpers

    private func startSDK(isEnabled: Bool, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: Self.self)
            $0.removeAllIntegrations()

            $0.experimental.enableMetrics = isEnabled

            configure?($0)
        }
    }

    private func givenSdkWithHub() throws {
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.removeAllIntegrations()

        options.experimental.enableMetrics = true

        let client = TestClient(options: options)
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
    }

    private func getSut() throws -> SentryMetricsIntegration<SentryDependencyContainer> {
        return try XCTUnwrap(SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration)
    }
}

// MARK: - Test Doubles

final class TestMetricsTelemetryBuffer: SentryMetricsTelemetryBuffer {
    var addMetricInvocations = Invocations<SentryMetric>()
    var captureMetricsInvocations = Invocations<Void>()

    func addMetric(_ metric: SentryMetric) {
        addMetricInvocations.record(metric)
    }

    @discardableResult
    func captureMetrics() -> TimeInterval {
        captureMetricsInvocations.record(())
        return 0.0
    }
}
