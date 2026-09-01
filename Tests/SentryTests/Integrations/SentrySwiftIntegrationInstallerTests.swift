@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentrySwiftIntegrationInstallerTests: XCTestCase {

    private var expectedReplayIntegrationCount: Int {
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        return 1
#else
        return 0
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
        options.enableMetrics = false
        options.enableCrashHandler = false
        #if canImport(MetricKit) && !os(tvOS)
        options.enableMetricKit = false
        #endif

        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        let names = try XCTUnwrap(testHub.installedIntegrationNames())
        XCTAssertEqual(names.count, expectedReplayIntegrationCount + 1)
        XCTAssertTrue(names.contains("SentrySwiftAsyncIntegration"))
        XCTAssertEqual(testHub.installedIntegrations().count, expectedReplayIntegrationCount + 1)
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
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
        options.enableMetrics = false
        options.enableCrashHandler = false
        #if canImport(MetricKit) && !os(tvOS)
        options.enableMetricKit = false
        #endif

        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        XCTAssertEqual(testHub.installedIntegrationNames().count, expectedReplayIntegrationCount)
        XCTAssertEqual(testHub.installedIntegrations().count, expectedReplayIntegrationCount)
    }
}
