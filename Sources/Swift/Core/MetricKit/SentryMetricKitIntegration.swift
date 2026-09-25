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
