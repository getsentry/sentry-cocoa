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
        SentrySDKInternal.fatalDetected = false
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
        let options = givenOptionsWithoutFatalSources()
        let heldReportStore = try givenHeldReportStore(options: options)
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertNil(heldReportStore.read())
    }

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testInstall_whenAPreviousLaunchLeftAHeldReport_shouldSetFatalDetected() throws {
        // -- Arrange --
        let options = givenOptionsWithoutFatalSources()
        let heldReportStore = try givenHeldReportStore(options: options)
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)

        // -- Assert --
        // The SDK reports that the last run didn't crash when no integration detected a fatal run
        // while it was installed. The held report is a fatal event this launch sends.
        XCTAssertTrue(SentrySDKInternal.fatalDetected)
    }

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testInstall_whenNoReportIsHeld_shouldNotSetFatalDetected() throws {
        // -- Arrange --
        let options = givenOptionsWithoutFatalSources()
        _ = try givenHeldReportStore(options: options)
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)

        // -- Assert --
        XCTAssertFalse(SentrySDKInternal.fatalDetected)
    }

    #if os(iOS) || os(macOS) || os(visionOS)
    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testInstall_whenMetricKitReportsRunEnds_shouldHoldWatchdogTerminations() throws {
        // -- Arrange --
        let options = givenOptionsWithoutFatalSources()
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]
        let heldReportStore = try givenHeldReportStore(options: options)
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)
        SentryDependencyContainer.sharedInstance().eventSourceCoordinator.submit(SentryEventSourceReport(
            source: .watchdogTermination,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: SentryCurrentRun.ID(rawValue: "run-1"),
            event: Event(level: .fatal)
        ))

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }
    #endif // os(iOS) || os(macOS) || os(visionOS)

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testInstall_whenMetricKitDoesNotReportRunEnds_shouldSendWatchdogTerminationsRightAway() throws {
        // -- Arrange --
        let options = givenOptionsWithoutFatalSources()
        let heldReportStore = try givenHeldReportStore(options: options)
        let client = try XCTUnwrap(TestClient(options: options))
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))

        // -- Act --
        SentrySwiftIntegrationInstaller.install(with: options)
        SentryDependencyContainer.sharedInstance().eventSourceCoordinator.submit(SentryEventSourceReport(
            source: .watchdogTermination,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: SentryCurrentRun.ID(rawValue: "run-1"),
            event: Event(level: .fatal)
        ))

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertNil(heldReportStore.read())
    }

    /// Options with which no integration reports a fatal run or waits for a late report of one.
    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    private func givenOptionsWithoutFatalSources() -> Options {
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
        #if canImport(MetricKit) && !os(tvOS)
        #if SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = []
        #else
        options.enableMetricKit = false
        #endif // SDK_V10
        #endif
        return options
    }

    /// The store the installed SDK reads the held report from, with work dispatched to the SDK's
    /// queue running right away.
    private func givenHeldReportStore(options: Options) throws -> SentryHeldFatalReportStore {
        let fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        addTeardownBlock { fileManager.deleteAllFolders() }
        SentryDependencyContainer.sharedInstance().fileManager = fileManager
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        return SentryHeldFatalReportStore(fileManager: fileManager)
    }
}
