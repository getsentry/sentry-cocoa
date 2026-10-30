#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegration<Dependencies: SysctlProvider & MetricKitRunProvider>: NSObject, SwiftIntegration {
    
    let mxManager: SentryMXManager
    /// The `SentryMetricManager` that receives diagnostics on xOS 27 and later, or `nil` when the
    /// `MXMetricManager` subscriber receives them.
    let metricManager: SentryMetricKitReportReceiver?

    init?(with options: Options, dependencies: Dependencies) {
        let enabledDiagnostics = Self.enabledDiagnostics(for: options)
        let enabledMetricReports = options.experimental.metrickit.enabledMetricReports
        guard !enabledDiagnostics.isEmpty || !enabledMetricReports.isEmpty else {
            return nil
        }

        let diagnosticCapturer = SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
            attachDiagnosticAsAttachment: options.enableMetricKitRawPayload,
            enabledDiagnostics: enabledDiagnostics,
            releaseName: options.releaseName,
            hangReportingMode: options.experimental.metrickit.hangReportingMode,
            processStartDate: dependencies.sysctlWrapper.processStartTimestamp,
            runStore: dependencies.metricKitRunStore,
            previousRunScope: dependencies.metricKitPreviousRunScope(options: options)
        )
        let metricManager = Self.makeMetricManager(enabledDiagnostics: enabledDiagnostics, diagnosticCapturer: diagnosticCapturer)
        self.metricManager = metricManager
        // Both receivers are needed on xOS 27 for now: SentryMetricManager only reads diagnostics,
        // so metric payloads still arrive through the MXMetricManager subscriber. The subscriber
        // ignores its diagnostic payloads while MetricManager delivers them, so the same
        // diagnostic can't be captured twice.
        mxManager = SentryMXManager(
            diagnosticCapturer: diagnosticCapturer,
            receivesDiagnosticPayloads: metricManager == nil,
            enabledMetricReports: enabledMetricReports,
            releaseName: options.releaseName
        )
        super.init()

        receiveReports()
    }
    
    static var name: String {
        "SentryMetricKitIntegration"
    }
    
    func uninstall() {
        metricManager?.pauseReports()
        mxManager.pauseReports()
    }

    private func receiveReports() {
        metricManager?.receiveReports()
        mxManager.receiveReports()
    }

    /// Creates the `SentryMetricManager` that replaces `MXMetricManager` for diagnostics on xOS 27
    /// and later, or returns `nil` when it isn't available or no diagnostics are enabled.
    private static func makeMetricManager(enabledDiagnostics: Set<SentryMXManager.Diagnostic>, diagnosticCapturer: SentryMXDiagnosticCapturer) -> SentryMetricKitReportReceiver? {
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), !enabledDiagnostics.isEmpty {
            return SentryMetricManager.make(diagnosticCapturer: diagnosticCapturer, runId: SentryMXRunStore.processRunId)
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
