#if os(iOS) || os(macOS)
import MetricKit

@available(macOS 12.0, *)
final class SentryMetricKitIntegration<Dependencies>: SwiftIntegration {
    
    let mxManager: SentryMXManager
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetricKit else {
            return nil
        }

        mxManager = SentryMXManager(inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes), attachDiagnosticAsAttachment: options.enableMetricKitRawPayload)

        mxManager.receiveReports()
    }
    
    static var name: String {
        "SentryMetricKitIntegration"
    }
    
    func uninstall() {
        mxManager.pauseReports()
    }
}

#endif
