// swiftlint:disable missing_docs
import Foundation

@objc @_spi(Private) public final class SentryExtraPackages: NSObject {
    private static let extraPackages = SentryMutex<Set<[String: String]>>([])

    @objc
    public static func addPackageName(_ name: String?, version: String?) {
        guard let name, let version else {
            return
        }

        let newPackage = ["name": name, "version": version]

        extraPackages.withLock { _ = $0.insert(newPackage) }
    }

    static func getPackages() -> Set<[String: String]> {
        extraPackages.withLock { Set($0) }
    }

    #if SENTRY_TEST || SENTRY_TEST_CI
    static func clear() {
        extraPackages.withLock { $0.removeAll() }
    }
    #endif
}
// swiftlint:enable missing_docs
