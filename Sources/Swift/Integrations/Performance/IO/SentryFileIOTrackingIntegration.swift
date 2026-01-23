@_implementationOnly import _SentryPrivate

typealias FileIOTrackingIntegrationProvider = FileIOTrackerProvider & NSDataSwizzlingProvider & NSFileManagerSwizzlingProvider

final class SentryFileIOTrackingIntegration<Dependencies: FileIOTrackingIntegrationProvider>: NSObject, SwiftIntegration {
    private let tracker: SentryFileIOTracker
    private let nsDataSwizzling: SentryNSDataSwizzling
    private let nsFileManagerSwizzling: SentryNSFileManagerSwizzling

    init?(with options: Options, dependencies: Dependencies) {
        // Check if tracing is enabled
        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because isTracingEnabled is disabled.")
            return nil
        }

        // Check if auto performance tracing is enabled
        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing is disabled.")
            return nil
        }

        // Check if file IO tracing is enabled
        guard options.enableFileIOTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableFileIOTracing is disabled.")
            return nil
        }

        self.tracker = dependencies.fileIOTracker
        self.nsDataSwizzling = dependencies.nsDataSwizzling
        self.nsFileManagerSwizzling = dependencies.nsFileManagerSwizzling

        super.init()

        tracker.enable()

        nsDataSwizzling.start(withOptions: options, tracker: tracker)
        nsFileManagerSwizzling.start(withOptions: options, tracker: tracker)
    }

    func uninstall() {
        tracker.disable()

        nsDataSwizzling.stop()
        nsFileManagerSwizzling.stop()
    }

    static var name: String {
        "SentryFileIOTrackingIntegration"
    }
}
