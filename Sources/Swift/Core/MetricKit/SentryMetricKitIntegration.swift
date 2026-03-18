#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

@available(macOS 12.0, *)
final class SentryMetricKitIntegration<Dependencies>: NSObject, SwiftIntegration {
    
    let mxManager: SentryMXManager
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetricKit else {
            return nil
        }

        mxManager = SentryMXManager(inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes), attachDiagnosticAsAttachment: options.enableMetricKitRawPayload)
        super.init()

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
