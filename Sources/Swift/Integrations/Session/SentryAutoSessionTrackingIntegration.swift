@_implementationOnly import _SentryPrivate

protocol AutoSessionTrackingProvider {
    func getSessionTracker(with options: Options) -> SessionTracker
    var processInfoWrapper: SentryProcessInfoSource { get }
}

final class SentryAutoSessionTrackingIntegration<Dependencies: AutoSessionTrackingProvider>: NSObject, SwiftIntegration {
    let tracker: SessionTracker
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoSessionTracking else { 
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoSessionTracking is disabled.")
            return nil 
        }
        
        guard !dependencies.processInfoWrapper.processDirectoryPath.hasSuffix(".systemextension") else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because it is not supported on system extensions.")
            return nil
        }

        tracker = dependencies.getSessionTracker(with: options)
        tracker.start()
    }
    
    func uninstall() {
        tracker.stop()
    }
    
    static var name: String {
        "SentryAutoSessionTrackingIntegration"
    }
}
