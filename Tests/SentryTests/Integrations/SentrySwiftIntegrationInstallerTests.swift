@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
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
        // Installing creates dependencies the container keeps, such as the event source
        // coordinator, which must not reach the next test.
        SentryDependencyContainer.reset()

        super.tearDown()
    }

    // We are not testing `SwiftAsyncIntegration`, but use it as an example for an installed integration
    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
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
        #if SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = []
        #else
        options.enableMetricKit = false
        #endif // SDK_V10
        #endif
        #if !SDK_V10
        // Metrics stays installed even when enableMetrics is false so manual APIs keep working.
        options.enableMetrics = false
        #endif // !SDK_V10

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

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
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
        #if SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = []
        #else
        options.enableMetricKit = false
        #endif // SDK_V10
        #endif
        #if !SDK_V10
        // Metrics remains installed regardless of enableMetrics.
        options.enableMetrics = false
        #endif // !SDK_V10

        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        XCTAssertEqual(testHub.installedIntegrationNames().count, expectedDefaultIntegrationCount)
        XCTAssertEqual(testHub.installedIntegrations().count, expectedDefaultIntegrationCount)
    }

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testInstall_whenAPreviousLaunchLeftAHeldReportAndNothingHoldsReports_shouldSendIt() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.enableAutoSessionTracking = false
        options.enableAutoPerformanceTracing = false
        options.tracesSampleRate = 0
        #if !SDK_V10
        options.enableAppHangTracking = false
        #endif // !SDK_V10
        options.enableWatchdogTerminationTracking = false
        options.enableSwizzling = false
        options.enableCrashHandler = false
        // Without MetricKit diagnostics no integration asks to hold reports, and without a crash
        // or a watchdog termination no fatal report is submitted in this launch.
        #if canImport(MetricKit) && !os(tvOS)
        #if SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = []
        #else
        options.enableMetricKit = false
        #endif // SDK_V10
        #endif

        let fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        defer { fileManager.deleteAllFolders() }
        SentryDependencyContainer.sharedInstance().fileManager = fileManager
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let heldReportStore = SentryHeldFatalReportStore(fileManager: fileManager)
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertNil(heldReportStore.read())
    }
}
