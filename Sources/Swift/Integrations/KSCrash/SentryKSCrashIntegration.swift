#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
import Foundation

// MARK: - Dependency Provider

/// Provides dependencies for `SentryKSCrashIntegration`.
typealias KSCrashIntegrationProvider = DateProviderProvider

// MARK: - SentryKSCrashIntegration

final class SentryKSCrashIntegration<Dependencies: KSCrashIntegrationProvider>: NSObject, SwiftIntegration {
    private weak var options: Options?

    // MARK: - Initialization

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

        self.options = options
        super.init()
 
        SentrySDKInternal.crashReporterInstalled = true
    }

    // MARK: - SwiftIntegration
    static var name: String {
        "SentryKSCrashIntegration"
    }

    func uninstall() {}
}
#endif
