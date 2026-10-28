#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation
import MetricKit

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryMXMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber)
    func remove(_ subscriber: MXMetricManagerSubscriber)
}
extension MXMetricManager: SentryMXMetricManager {}
#else
typealias SentryMXMetricManager = MXMetricManager
#endif

/// Receives the payloads of the legacy `MXMetricManager` subscriber API.
final class SentryMXManager: NSObject, SentryMetricKitReportReceiver {
    // MARK: - Types

    typealias Diagnostic = SentryMetricKit.DiagnosticReport
    typealias MetricReport = SentryMetricKit.MetricReport

    // MARK: - Properties

    private let metricManager: SentryMXMetricManager
    let diagnosticCapturer: SentryMXDiagnosticCapturer
    /// Whether diagnostic payloads are captured. `SentryMetricManager` replaces the subscriber for
    /// diagnostics on xOS 27 and later, so the same diagnostic can't be captured twice.
    let receivesDiagnosticPayloads: Bool
    let enabledMetricReports: Set<MetricReport>
    let metricsApi: SentryInternalMetricsApi
    let releaseResolver: SentryMXReleaseResolver

    init(
        metricManager: SentryMXMetricManager = MXMetricManager.shared,
        diagnosticCapturer: SentryMXDiagnosticCapturer,
        receivesDiagnosticPayloads: Bool = true,
        enabledMetricReports: Set<MetricReport> = [],
        metricsApi: SentryInternalMetricsApi = SentryMetricsApi(dependencies: SentryDependencyContainer.sharedInstance()),
        releaseName: String? = nil,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        self.metricManager = metricManager
        self.diagnosticCapturer = diagnosticCapturer
        self.receivesDiagnosticPayloads = receivesDiagnosticPayloads
        self.enabledMetricReports = enabledMetricReports
        self.metricsApi = metricsApi
        self.releaseResolver = SentryMXReleaseResolver(releaseName: releaseName, bundleInfo: bundleInfo)
        super.init()
    }

    func receiveReports() {
        SentrySDKLog.info("Started receiving reports from MetricKit")
        metricManager.add(self)
    }

    func pauseReports() {
        SentrySDKLog.info("Paused receiving reports from MetricKit")
        metricManager.remove(self)
    }
}

extension SentryMXManager: MXMetricManagerSubscriber {
    // The macOS SDK before Xcode 26 marks MXMetricPayload unavailable, and MetricKit only
    // delivers metric payloads from macOS 26.
    #if os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))
    func didReceive(_ payloads: [MXMetricPayload]) {
        guard !enabledMetricReports.isEmpty else {
            SentrySDKLog.debug("MetricKit metric reports are not enabled, skipping \(payloads.count) metric payloads")
            return
        }
        SentrySDKLog.info("Received \(payloads.count) MetricKit metric payloads")
        payloads.forEach { payload in
            process(metricPayload: payload)
        }
    }
    #endif // os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard receivesDiagnosticPayloads else {
            SentrySDKLog.debug("Diagnostics are received from MetricManager, ignoring \(payloads.count) MetricKit diagnostic payloads")
            return
        }
        process(diagnosticPayloads: payloads)
    }

    func process(diagnosticPayloads payloads: [MXDiagnosticPayload]) {
        SentrySDKLog.info("Received \(payloads.count) MetricKit diagnostic payloads")
        payloads.forEach { payload in
            let timestamp = payload.timeStampBegin
            process(payload.crashDiagnostics, with: SentryMXCrashDiagnosticProcessor.self, timestamp: timestamp)
            process(payload.diskWriteExceptionDiagnostics, with: SentryMXDiskWriteExceptionDiagnosticProcessor.self, timestamp: timestamp)
            process(payload.cpuExceptionDiagnostics, with: SentryMXCPUExceptionDiagnosticProcessor.self, timestamp: timestamp)
            process(payload.hangDiagnostics, with: SentryMXHangDiagnosticProcessor.self, timestamp: timestamp)
            #if os(iOS) || os(visionOS)
            if #available(iOS 16.0, *) {
                process(payload.appLaunchDiagnostics, with: SentryMXAppLaunchDiagnosticProcessor.self, timestamp: timestamp)
            }
            #endif // os(iOS) || os(visionOS)
        }
    }

    private func process<Processor: SentryMXDiagnosticProcessor>(
        _ diagnostics: [Processor.LegacyDiagnostic]?,
        with processor: Processor.Type,
        timestamp: Date
    ) {
        guard let diagnostics else {
            return
        }
        SentrySDKLog.info("Received \(diagnostics.count) MetricKit \(Processor.report) diagnostics")
        diagnostics.forEach { diagnostic in
            diagnosticCapturer.capture(Processor.diagnostic(of: diagnostic, timestamp: timestamp))
        }
    }
}

#endif
