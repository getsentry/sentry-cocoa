import Foundation

@objc @_spi(Private) public final class SentryExtraPackages: NSObject {
    private static var extraPackages = Set<[String: String]>()
    private static let syncQueue = DispatchQueue(label: "io.sentry.SentryExtraPackages.sync", attributes: .concurrent)

    @objc
    public static func addPackageName(_ name: String?, version: String?) {
        guard let name, let version else {
            return
        }

        let newPackage = ["name": name, "version": version]

        // Thread-safe write using a barrier block on a concurrent queue.
        // Ensures no other reads or writes happen during this insertion.
        syncQueue.async(flags: .barrier) {
            extraPackages.insert(newPackage)
        }
    }

    @objc
    public static func getPackages() -> NSMutableSet {
        var copy: Set<[String: String]> = []
        // Thread-safe synchronous read on a concurrent queue.
        // Multiple reads can happen concurrently unless a write barrier is active.
        // Returns a copy to prevent external mutation of internal state.
        syncQueue.sync {
            copy = extraPackages
        }
        return NSMutableSet(set: copy as NSSet)
    }

    #if SENTRY_TEST || SENTRY_TEST_CI
    static func clear() {
        syncQueue.async(flags: .barrier) {
            extraPackages.removeAll()
        }
    }
    #endif
}
