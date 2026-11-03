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
    /// Captures the diagnostic payloads, or `nil` when the subscriber doesn't deliver diagnostics,
    /// such as on xOS 27 and later, where `SentryMetricManager` delivers them.
    let diagnosticCapturer: SentryMXDiagnosticCapturer?
    /// Records the metric payloads, or `nil` when the subscriber doesn't deliver metrics, such as
    /// on iOS and macOS 27 and later, where `SentryMetricManager` delivers them.
    let metricRecorder: SentryMXMetricRecorder?

    init(
        metricManager: SentryMXMetricManager = MXMetricManager.shared,
        diagnosticCapturer: SentryMXDiagnosticCapturer? = nil,
        metricRecorder: SentryMXMetricRecorder? = nil
    ) {
        self.metricManager = metricManager
        self.diagnosticCapturer = diagnosticCapturer
        self.metricRecorder = metricRecorder
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
        guard let metricRecorder else {
            SentrySDKLog.debug("MetricKit metric payloads are not received, skipping \(payloads.count) metric payloads")
            return
        }
        SentrySDKLog.info("Received \(payloads.count) MetricKit metric payloads")
        payloads.forEach { payload in
            metricRecorder.record(metricPayload: payload)
        }
    }
    #endif // os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let diagnosticCapturer else {
            SentrySDKLog.debug("MetricKit diagnostic payloads are not received, skipping \(payloads.count) diagnostic payloads")
            return
        }
        SentrySDKLog.info("Received \(payloads.count) MetricKit diagnostic payloads")
        payloads.forEach { payload in
            let timestamp = payload.timeStampBegin
            process(payload.crashDiagnostics, with: SentryMXCrashDiagnosticProcessor.self, timestamp: timestamp, capturer: diagnosticCapturer)
            process(payload.diskWriteExceptionDiagnostics, with: SentryMXDiskWriteExceptionDiagnosticProcessor.self, timestamp: timestamp, capturer: diagnosticCapturer)
            process(payload.cpuExceptionDiagnostics, with: SentryMXCPUExceptionDiagnosticProcessor.self, timestamp: timestamp, capturer: diagnosticCapturer)
            process(payload.hangDiagnostics, with: SentryMXHangDiagnosticProcessor.self, timestamp: timestamp, capturer: diagnosticCapturer)
            #if os(iOS) || os(visionOS)
            if #available(iOS 16.0, *) {
                process(payload.appLaunchDiagnostics, with: SentryMXAppLaunchDiagnosticProcessor.self, timestamp: timestamp, capturer: diagnosticCapturer)
            }
            #endif // os(iOS) || os(visionOS)
        }
    }

    private func process<Processor: SentryMXDiagnosticProcessor>(
        _ diagnostics: [Processor.LegacyDiagnostic]?,
        with processor: Processor.Type,
        timestamp: Date,
        capturer diagnosticCapturer: SentryMXDiagnosticCapturer
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
