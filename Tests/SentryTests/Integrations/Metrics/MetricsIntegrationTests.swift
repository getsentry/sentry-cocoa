import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class MetricsIntegrationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests
    
    func testStartSDK_whenIntegrationIsNotEnabled_shouldNotBeInstalled() {
        // -- Act --
        startSDK(isEnabled: false)

        // -- Assert --
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 0)
    }

    func testStartSDK_whenIntegrationIsEnabled_shouldBeInstalled() {
        // -- Act --
        startSDK(isEnabled: true)

        // -- Assert --
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().count, 1)
    }
    
    func testMetricsIntegration_AddsMetricsToBatcher() throws {
        // -- Arrange --
        startSDK(isEnabled: true)
        let integration = try getSut()
        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            spanId: nil,
            name: "test.metric",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        // -- Act --
        integration.addMetric(metric, scope: scope)
        
        // -- Assert --
        // Metric should be added to batcher (no crash)
        // Flush to verify it's processed
        SentrySDK.flush(timeout: 1.0)
    }
    
    func testMetricsIntegration_Uninstall_FlushesMetrics() throws {
        // -- Arrange --
        startSDK(isEnabled: true)
        let integration = try getSut()
        let scope = Scope()
        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId(),
            spanId: nil,
            name: "test.metric",
            value: NSNumber(value: 1),
            type: .counter,
            unit: nil,
            attributes: [:]
        )
        
        integration.addMetric(metric, scope: scope)
        
        // -- Act --
        integration.uninstall()
        
        // -- Assert --
        // Uninstall should flush metrics (no crash)
    }

    // MARK: - Helpers

    private func startSDK(isEnabled: Bool, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: MetricsIntegrationTests.self)
            $0.removeAllIntegrations()

            $0.enableMetrics = isEnabled

            configure?($0)
        }
        SentrySDKInternal.currentHub().startSession()
    }

    private func getSut() throws -> MetricsIntegration<SentryDependencyContainer> {
        return try XCTUnwrap(SentrySDKInternal.currentHub().getInstalledIntegration(MetricsIntegration<SentryDependencyContainer>.self) as? MetricsIntegration)
    }
}
