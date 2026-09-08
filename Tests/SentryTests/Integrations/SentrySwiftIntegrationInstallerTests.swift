@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentrySwiftIntegrationInstallerTests: XCTestCase {

    private var expectedDefaultIntegrationCount: Int {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        // Replay + Metrics
        return 2
#else
        // Metrics
        return 1
#endif
    }

    override func tearDown() {
        SentrySDKInternal.setCurrentHub(nil)

        super.tearDown()
    }

    // We are not testing `SwiftAsyncIntegration`, but use it as an example for an installed integration
    func testInstall_AddsInstalledIntegrations() throws {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.debug = true
        options.swiftAsyncStacktraces = true

        // Disable other integrations
        options.enableAutoSessionTracking = false
        options.enableAutoPerformanceTracing = false
        options.tracesSampleRate = 0
        #if !SDK_V10
        options.enableAppHangTracking = false
        #endif // !SDK_V10
        options.enableWatchdogTerminationTracking = false
        options.enableSwizzling = false
        options.enableCrashHandler = false
        #if canImport(MetricKit) && !os(tvOS)
        options.enableMetricKit = false
        #endif
        // Metrics stays installed even when enableMetrics is false so manual APIs keep working.
        options.enableMetrics = false

        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        let names = try XCTUnwrap(testHub.installedIntegrationNames())
        XCTAssertEqual(names.count, expectedDefaultIntegrationCount + 1)
        XCTAssertEqual(testHub.installedIntegrations().count, expectedDefaultIntegrationCount + 1)
        XCTAssertTrue(names.contains("SentrySwiftAsyncIntegration"))
        XCTAssertTrue(names.contains("SentryMetricsIntegration"))
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        XCTAssertTrue(names.contains("SentrySessionReplayIntegration"))
#endif
    }

    func testInstall_WithDisabledIntegration_DoesNotAddIntegration() {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.debug = true
        options.swiftAsyncStacktraces = false

        // Disable other integrations
        options.enableAutoSessionTracking = false
        options.enableAutoPerformanceTracing = false
        options.tracesSampleRate = 0
        #if !SDK_V10
        options.enableAppHangTracking = false
        #endif // !SDK_V10
        options.enableWatchdogTerminationTracking = false
        options.enableSwizzling = false
        options.enableCrashHandler = false
        #if canImport(MetricKit) && !os(tvOS)
        options.enableMetricKit = false
        #endif
        // Metrics remains installed regardless of enableMetrics.
        options.enableMetrics = false

        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        XCTAssertEqual(testHub.installedIntegrationNames().count, expectedDefaultIntegrationCount)
        XCTAssertEqual(testHub.installedIntegrations().count, expectedDefaultIntegrationCount)
    }
}
