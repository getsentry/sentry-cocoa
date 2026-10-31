#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegration<Dependencies: SysctlProvider>: NSObject, SwiftIntegration {
    
    /// Captures the enabled diagnostics, or `nil` when none is enabled.
    let diagnosticCapturer: SentryMXDiagnosticCapturer?
    /// Records the enabled metrics, or `nil` when none is enabled.
    let metricRecorder: SentryMXMetricRecorder?
    /// The `SentryMetricManager` that receives the reports `MetricManager` delivers on xOS 27 and
    /// later, or `nil` when it doesn't deliver any enabled report.
    let metricManager: SentryMetricKitReportReceiver?
    /// The `MXMetricManager` subscriber that receives the reports `MetricManager` doesn't
    /// deliver, or `nil` when `MetricManager` delivers every enabled report.
    let mxManager: SentryMXManager?

    init?(with options: Options, dependencies: Dependencies) {
        let enabledDiagnostics = Self.enabledDiagnostics(for: options)
        let enabledMetricReports = options.experimental.metrickit.enabledMetricReports
        guard !enabledDiagnostics.isEmpty || !enabledMetricReports.isEmpty else {
            return nil
        }

        let diagnosticCapturer = enabledDiagnostics.isEmpty ? nil : SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
            attachDiagnosticAsAttachment: options.enableMetricKitRawPayload,
            enabledDiagnostics: enabledDiagnostics,
            releaseName: options.releaseName,
            hangReportingMode: options.experimental.metrickit.hangReportingMode,
            processStartDate: dependencies.sysctlWrapper.processStartTimestamp
        )
        let metricRecorder = enabledMetricReports.isEmpty ? nil : SentryMXMetricRecorder(
            enabledMetricReports: enabledMetricReports,
            releaseName: options.releaseName
        )
        self.diagnosticCapturer = diagnosticCapturer
        self.metricRecorder = metricRecorder

        // Each report comes from exactly one API, so the same diagnostic or metric can't be sent
        // twice. MetricManager replaces MXMetricManager on xOS 27, except for metrics on
        // visionOS, which only the subscriber reports.
        let metricManagerDiagnosticCapturer = Self.metricManagerDeliversDiagnostics ? diagnosticCapturer : nil
        let metricManagerMetricRecorder = Self.metricManagerDeliversMetrics ? metricRecorder : nil
        metricManager = Self.makeMetricManager(diagnosticCapturer: metricManagerDiagnosticCapturer, metricRecorder: metricManagerMetricRecorder)

        let subscriberDiagnosticCapturer = metricManagerDiagnosticCapturer == nil ? diagnosticCapturer : nil
        let subscriberMetricRecorder = metricManagerMetricRecorder == nil ? metricRecorder : nil
        if subscriberDiagnosticCapturer != nil || subscriberMetricRecorder != nil {
            mxManager = SentryMXManager(diagnosticCapturer: subscriberDiagnosticCapturer, metricRecorder: subscriberMetricRecorder)
        } else {
            mxManager = nil
        }
        super.init()

        metricManager?.receiveReports()
        mxManager?.receiveReports()
    }
    
    static var name: String {
        "SentryMetricKitIntegration"
    }
    
    func uninstall() {
        metricManager?.pauseReports()
        mxManager?.pauseReports()
    }

    /// Whether `MetricManager` delivers diagnostics, which it does on xOS 27 and later.
    ///
    /// The availability check covers the OS the app runs on, and the compiler check the SDK it was
    /// built with: `SentryMetricManager` only exists when built with Xcode 27 or later, so an app
    /// built with Xcode 26 must keep the `MXMetricManager` subscriber even on xOS 27.
    private static var metricManagerDeliversDiagnostics: Bool {
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            return true
        }
        #endif // compiler(>=6.4)
        return false
    }

    /// Whether `MetricManager` delivers metrics, which it does on iOS and macOS 27 and later but
    /// not on visionOS.
    private static var metricManagerDeliversMetrics: Bool {
        #if (os(iOS) || os(macOS)) && compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, *) {
            return true
        }
        #endif // (os(iOS) || os(macOS)) && compiler(>=6.4)
        return false
    }

    /// Creates the `SentryMetricManager` that receives the given reports from `MetricManager`, or
    /// returns `nil` when it receives none.
    private static func makeMetricManager(
        diagnosticCapturer: SentryMXDiagnosticCapturer?,
        metricRecorder: SentryMXMetricRecorder?
    ) -> SentryMetricKitReportReceiver? {
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), diagnosticCapturer != nil || metricRecorder != nil {
            return SentryMetricManager(diagnosticCapturer: diagnosticCapturer, metricRecorder: metricRecorder)
        }
        #endif // compiler(>=6.4)
        return nil
    }

    private static func enabledDiagnostics(for options: Options) -> Set<SentryMXManager.Diagnostic> {
        let enabledDiagnosticReports = options.experimental.metrickit.enabledDiagnosticReports
        #if SDK_V10
        return enabledDiagnosticReports
        #else
        // Before v10 the integration is opt-in, and enableMetricKit keeps capturing the
        // diagnostics it always captured unless the app chooses its own set.
        guard enabledDiagnosticReports.isEmpty else {
            return enabledDiagnosticReports
        }
        return options.enableMetricKit ? [.cpuException, .diskWriteException, .hang] : []
        #endif // SDK_V10
    }
}

// Keep this extension with the integration so static links retain its Objective-C category
// even when MetricKit is disabled. A standalone extension file can be omitted without -ObjC,
// leaving SentryClient's isMetricKitEvent message with no implementation.
extension Event {
    // swiftlint:disable:next missing_docs
    @objc @_spi(Private) public func isMetricKitEvent() -> Bool {
        guard let mechanism = exceptions?.first?.mechanism, exceptions?.count == 1 else {
            return false
        }

        return SentryMXManager.Diagnostic.all.contains { $0.mechanism == mechanism.type }
    }
}

#endif
