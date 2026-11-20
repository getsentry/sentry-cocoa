@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#if SWIFT_PACKAGE
import _SentryPrivate
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegrationInitTests: XCTestCase {

#if !SDK_V10
    func testOptionEnabled_MetricKitManagerInitialized() {
          let options = Options()
          options.enableMetricKit = true
          let sut = SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
          XCTAssertNotNil(sut)
    }

    func testOptionDisabled_MetricKitManagerNotInitialized() {
          let options = Options()
          options.enableMetricKit = false
          let sut = SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
          XCTAssertNil(sut)
    }

    func testInit_whenDiagnosticReportsNotConfigured_shouldUseDefaultDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetricKit = true

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        XCTAssertEqual(sut.diagnosticCapturer?.enabledDiagnostics, [.cpuException, .diskWriteException, .hang])
    }

    func testInit_whenMetricKitDisabledAndDiagnosticReportsConfigured_shouldUseConfiguredDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetricKit = false
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        // Before v10 a configured set of reports opts in on its own.
        XCTAssertEqual(sut.diagnosticCapturer?.enabledDiagnostics, [.hang])
    }
#endif // !SDK_V10

    func testInit_whenDiagnosticsAreEnabled_shouldRecordTheRunIdForMetricKit() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]
        let dependencies = SentryDependencyContainer.sharedInstance()
        let fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        defer { fileManager.deleteAllFolders() }
        let previousFileManager = dependencies.fileManager
        let previousDispatchQueueWrapper = dependencies.dispatchQueueWrapper
        dependencies.fileManager = fileManager
        dependencies.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        defer {
            dependencies.fileManager = previousFileManager
            dependencies.dispatchQueueWrapper = previousDispatchQueueWrapper
        }

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: dependencies))

        // -- Assert --
        XCTAssertNotNil(sut.diagnosticCapturer?.runIdDecoder)
        let store = SentryMXRunIdRecordStore(fileManager: fileManager, dateProvider: dependencies.dateProvider)
        let record = try XCTUnwrap(store.records().first { $0.runId == dependencies.currentRun.id })
        // The process-wide crumb spells the run ID of the process; a crumb parked earlier for the
        // same run ID is reused, so the record always holds its frames.
        XCTAssertEqual(record.threadCrumbAddresses.count, 32)
    }

    func testInit_whenCrashDiagnosticsAreEnabled_shouldHoldWatchdogTerminations() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]
        let dependencies = try givenDependencies(options: options)
        defer { dependencies.fileManager?.deleteAllFolders() }

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: dependencies))

        // -- Assert --
        XCTAssertEqual(dependencies.holdPolicy.heldSources, [.watchdogTermination: 30])
        sut.uninstall()
        XCTAssertEqual(dependencies.holdPolicy.heldSources, [:])
    }

    func testInit_whenMemoryExceptionDiagnosticsAreEnabled_shouldHoldWatchdogTerminations() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.metrickit.enabledDiagnosticReports = [.memoryException]
        let dependencies = try givenDependencies(options: options)
        defer { dependencies.fileManager?.deleteAllFolders() }

        // -- Act --
        _ = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: dependencies))

        // -- Assert --
        XCTAssertEqual(dependencies.holdPolicy.heldSources, [.watchdogTermination: 30])
    }

    func testInit_whenOnlyOtherDiagnosticsAreEnabled_shouldNotHoldWatchdogTerminations() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]
        let dependencies = try givenDependencies(options: options)
        defer { dependencies.fileManager?.deleteAllFolders() }

        // -- Act --
        _ = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: dependencies))

        // -- Assert --
        XCTAssertEqual(dependencies.holdPolicy.heldSources, [:])
    }

    func testInit_whenRunIdsCantBeRecorded_shouldNotHoldWatchdogTerminations() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]
        let dependencies = TestMetricKitDependencies(fileManager: nil)

        // -- Act --
        _ = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: dependencies))

        // -- Assert --
        XCTAssertEqual(dependencies.holdPolicy.heldSources, [:])
    }

    private func givenDependencies(options: Options) throws -> TestMetricKitDependencies {
        let fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        return TestMetricKitDependencies(fileManager: fileManager)
    }

    func testInit_whenDiagnosticsAreDisabled_shouldNotRecordTheRunId() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = []
        options.experimental.metrickit.enabledMetricReports = [.cpuCumulativeTime]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        XCTAssertNil(sut.diagnosticCapturer)
    }

    func testInit_whenDiagnosticReportsConfigured_shouldUseConfiguredDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.hang, .crash]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        XCTAssertEqual(sut.diagnosticCapturer?.enabledDiagnostics, [.hang, .crash])
    }

    func testInit_whenDiagnosticReportsEmpty_shouldDependOnSDKVersion() throws {
        // -- Arrange --
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10
        options.experimental.metrickit.enabledDiagnosticReports = []

        // -- Act --
        let sut = SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
#if SDK_V10
        XCTAssertNil(sut)
#else
        // Before v10 an empty set leaves the decision to enableMetricKit.
        XCTAssertEqual(try XCTUnwrap(sut).diagnosticCapturer?.enabledDiagnostics, [.cpuException, .diskWriteException, .hang])
#endif
    }

    func testInit_whenOnlyMetricReportsConfigured_shouldEnableIntegrationWithoutDiagnostics() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = []
        options.experimental.metrickit.enabledMetricReports = [.cpuCumulativeTime, .exitForegroundWatchdog]

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        XCTAssertEqual(sut.metricRecorder?.enabledMetricReports, [.cpuCumulativeTime, .exitForegroundWatchdog])
        XCTAssertNil(sut.diagnosticCapturer)
    }

    func testInit_whenMetricReportsNotConfigured_shouldNotEnableMetricReports() throws {
        // -- Arrange --
        let options = Options()
        #if !SDK_V10
        options.enableMetricKit = true
        #endif // !SDK_V10

        // -- Act --
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))

        // -- Assert --
        XCTAssertNil(sut.metricRecorder)
    }

    func testInit_whenDefaultOptions_shouldDependOnSDKVersion() throws {
        // -- Arrange --
        let options = Options()

        // -- Act --
        let sut = SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(try XCTUnwrap(sut).diagnosticCapturer?.enabledDiagnostics, [.cpuException, .diskWriteException, .hang, .appLaunch])
#else
        XCTAssertNil(sut)
#endif
    }
}

/// Records which sources an integration asked to hold.
private final class TestEventSourceHoldPolicy: SentryEventSourceHoldPolicy {
    var heldSources: [SentryEventSource: TimeInterval] = [:]

    func hold(fatalReportsOf source: SentryEventSource, for duration: TimeInterval) {
        heldSources[source] = duration
    }

    func stopHolding(fatalReportsOf source: SentryEventSource) {
        heldSources[source] = nil
    }
}

private struct TestMetricKitDependencies: SysctlProvider, EventSourceSinkProvider, EventSourceHoldPolicyProvider, CurrentRunProvider, FileManagerProvider, DateProviderProvider, DispatchQueueWrapperProvider {
    let sysctlWrapper = SentrySysctl()
    let eventSourceSink: SentryEventSourceSink = TestEventSourceSink()
    let holdPolicy = TestEventSourceHoldPolicy()
    var eventSourceHoldPolicy: SentryEventSourceHoldPolicy { holdPolicy }
    // The thread crumb is parked once per process for the run ID of the container's run, so
    // another run ID would get no crumb and block the tests that need one.
    let currentRun = SentryDependencyContainer.sharedInstance().currentRun
    let fileManager: SentryFileManager?
    let dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider()
    let dispatchQueueWrapper: SentryDispatchQueueWrapper = TestSentryDispatchQueueWrapper()
}

#endif // os(iOS) || os(macOS) || os(visionOS)
