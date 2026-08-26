@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentrySwiftIntegrationInstallerTests: XCTestCase {

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
#if SENTRY_DISABLE_SENTRYCRASH_V10
        // KSCRASH_TODO(GH-8725): V10 temporarily omits the Swift async integration.
        // Acceptance: SCV10-011 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        XCTAssertEqual(names.count, 0)
        XCTAssertFalse(names.contains("SentrySwiftAsyncIntegration"))
        XCTAssertEqual(testHub.installedIntegrations().count, 0)
#else
        XCTAssertEqual(names.count, 1)
        XCTAssertTrue(names.contains("SentrySwiftAsyncIntegration"))
        XCTAssertEqual(testHub.installedIntegrations().count, 1)
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
        XCTAssertEqual(testHub.installedIntegrationNames().count, 0)
        XCTAssertEqual(testHub.installedIntegrations().count, 0)
    }
}
