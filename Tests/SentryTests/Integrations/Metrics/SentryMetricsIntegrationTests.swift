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
    
    func testAddMetric_whenMetricAdded_shouldAddToBatcher() throws {
        // -- Arrange --
        try givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient, "Hub Client is not a `TestClient`")

        let integration = try getSut()

        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            name: "test.metric",
            value: 1,
            type: .counter,
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
        XCTAssertEqual(1, capturedMetrics.count.intValue, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")

        // Assert no furhter invocations
        XCTAssertEqual(1, client.captureMetricsDataInvocations.count, "Metrics should be captured")
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
            value: 1,
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        integration.addMetric(metric, scope: scope)
        
        // -- Act --
        integration.uninstall()
        
        // -- Assert --
        let capturedMetrics = try XCTUnwrap(client.captureMetricsDataInvocations.first)
        XCTAssertEqual(1, capturedMetrics.count.intValue, "Should capture 1 metric")
        XCTAssertFalse(capturedMetrics.data.isEmpty, "Captured metrics data should not be empty")

        // Assert no furhter invocations
        XCTAssertEqual(1, client.captureMetricsDataInvocations.count, "Uninstall should flush metrics")
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
        let integration = try XCTUnwrap(SentryMetricsIntegration<SentryDependencyContainer>(with: options, dependencies: dependencies) as? SentryIntegrationProtocol)
        hub.addInstalledIntegration(integration, name: SentryMetricsIntegration<SentryDependencyContainer>.name)

        hub.startSession()
    }

    private func getSut() throws -> SentryMetricsIntegration<SentryDependencyContainer> {
        return try XCTUnwrap(SentrySDKInternal.currentHub().getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration)
    }
}
