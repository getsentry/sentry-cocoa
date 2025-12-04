final class AutoSessionTrackingIntegration: NSObject, SwiftIntegration {
    
    private let tracker: SessionTracker
    
    init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard options.enableAutoSessionTracking else {
            return nil
        }

        tracker = dependencies.getSessionTracker(with: options)
        tracker.start()
    }
    
    func uninstall() {
        tracker.stop()
    }
    
    static var name = "SentryAutoSessionTrackingIntegration"
}
