// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

typealias CoreDataTrackingIntegrationProvider = SentryCoreDataSwizzlingProvider & SentryCoreDataTrackerBuilder

final class SentryCoreDataTrackingIntegration<Dependencies: CoreDataTrackingIntegrationProvider>: SwiftIntegration {
    private let tracker: SentryCoreDataTracker
    private let coreDataSwizzling: SentryCoreDataSwizzling

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing is disabled.")
            return nil
        }

        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because tracing is disabled.")
            return nil
        }

        guard options.enableCoreDataTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCoreDataTracing is disabled.")
            return nil
        }

        self.tracker = dependencies.getCoreDataTracker(options)
        self.coreDataSwizzling = dependencies.coreDataSwizzling

        self.coreDataSwizzling.start(with: tracker)
    }

    func uninstall() {
        self.coreDataSwizzling.stop()
    }

    static var name: String {
        "SentryCoreDataTrackingIntegration"
    }
}
// swiftlint:enable missing_docs
