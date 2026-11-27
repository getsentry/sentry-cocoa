@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
#if SWIFT_PACKAGE
import _SentryPrivate
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegrationInitTests: XCTestCase {

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
        options.experimental.metrickit.enabledDiagnosticReports = []

        // -- Act --
        let sut = SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
        XCTAssertNil(sut)
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
        XCTAssertEqual(try XCTUnwrap(sut).diagnosticCapturer?.enabledDiagnostics, [.cpuException, .diskWriteException, .hang, .appLaunch])
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
