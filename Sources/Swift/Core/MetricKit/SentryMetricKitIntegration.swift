#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegration<Dependencies>: NSObject, SwiftIntegration {
    
    let mxManager: SentryMXManager
    
    init?(with options: Options, dependencies: Dependencies) {
        let enabledDiagnostics = Self.enabledDiagnostics(for: options)
        guard !enabledDiagnostics.isEmpty else {
            return nil
        }

        mxManager = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
            attachDiagnosticAsAttachment: options.enableMetricKitRawPayload,
            enabledDiagnostics: enabledDiagnostics,
            releaseName: options.releaseName
        )
        super.init()

        mxManager.receiveReports()
    }
    
    static var name: String {
        "SentryMetricKitIntegration"
    }
    
    func uninstall() {
        mxManager.pauseReports()
    }

    private static func enabledDiagnostics(for options: Options) -> Set<SentryMXManager.Diagnostic> {
        let enabledDiagnosticReports = options.experimental.metricKit.enabledDiagnosticReports
        #if SDK_V10
        return options.enableMetricKit ? enabledDiagnosticReports : []
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
