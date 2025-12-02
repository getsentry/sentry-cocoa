@_implementationOnly import _SentryPrivate

protocol SessionTrackerProvider {
    func getSessionTracker(with options: Options) -> SessionTracker
}

final class SentryAutoSessionTrackingIntegration<Dependencies: SessionTrackerProvider>: NSObject, SwiftIntegration {
    let tracker: SessionTracker
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoSessionTracking else { return nil }

        tracker = dependencies.getSessionTracker(with: options)
        tracker.start()
    }
    
    func uninstall() {
        stop()
    }
    
    func stop() {
        tracker.stop()
    }
    
    static var name: String {
        "SentryAutoSessionTrackingIntegration"
    }
}
