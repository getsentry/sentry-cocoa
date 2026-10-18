internal import _SentryPrivate
import CoreData

private enum SentryCoreDataSwizzleKeys {
    static let fetch = SentryTypedSwizzle.Key()
    static let save = SentryTypedSwizzle.Key()
}

final class SentryCoreDataTrackingIntegration<Dependencies: SentryCoreDataTrackerBuilder>: NSObject, SwiftIntegration {
    private let tracker: SentryCoreDataTrackerProtocol

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

        super.init()

        SentryCoreDataTrackerProxy.shared.setTarget(tracker)
        Self.swizzleManagedObjectContext()
    }

    func uninstall() {
        SentryCoreDataTrackerProxy.shared.removeTarget(tracker)
    }

    static var name: String {
        "SentryCoreDataTrackingIntegration"
    }

    private static func swizzleManagedObjectContext() {
        SentryTypedSwizzle.instanceMethod(
            in: NSManagedObjectContext.self,
            method: .managedObjectContextFetch(NSManagedObjectContext.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryCoreDataSwizzleKeys.fetch
        ) { context, request, error, original in
            guard let tracker = SentryCoreDataTrackerProxy.shared.target else {
                return original(request, error)
            }
            return tracker.managedObjectContext(context, executeFetchRequest: request, error: error, originalImp: original)
        }

        SentryTypedSwizzle.instanceMethod(
            in: NSManagedObjectContext.self,
            method: .managedObjectContextSave(NSManagedObjectContext.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryCoreDataSwizzleKeys.save
        ) { context, error, original in
            guard let tracker = SentryCoreDataTrackerProxy.shared.target else {
                return original(error)
            }
            return tracker.managedObjectContext(context, save: error, originalImp: original)
        }
    }
}
