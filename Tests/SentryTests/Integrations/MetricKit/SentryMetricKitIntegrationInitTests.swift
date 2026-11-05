@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
#else
@_spi(Private) @testable import Sentry
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

#endif // os(iOS) || os(macOS) || os(visionOS)
