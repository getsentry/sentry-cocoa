#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitIntegration<Dependencies>: NSObject, SwiftIntegration {
    
    let mxManager: SentryMXManager
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetricKit else {
            return nil
        }

        mxManager = SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
            attachDiagnosticAsAttachment: options.enableMetricKitRawPayload,
            enabledDiagnostics: [.cpuException, .diskWriteException, .hang]
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
}

#endif
