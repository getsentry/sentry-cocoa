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
        XCTAssertEqual(SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().first, "Metrics")
    }

    // MARK: - Helpers

    private func startSDK(isEnabled: Bool, configure: ((Options) -> Void)? = nil) {
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: MetricsIntegrationTests.self)
            $0.removeAllIntegrations()

            $0.experimental.enableMetrics = isEnabled

            configure?($0)
        }
    }
}
