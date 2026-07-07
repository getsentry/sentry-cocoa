#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
import Foundation
internal import KSCrashRecording

/// Provides dependencies for `SentryKSCrashIntegration`.
typealias KSCrashIntegrationProvider = KSCrashInstallerProvider

extension SentryKSCrash {
    final class Integration<Dependencies: KSCrashIntegrationProvider>: NSObject, SwiftIntegration {
        private let options: Options

        // MARK: - Initialization
        init?(with options: Options, dependencies: Dependencies) {
            guard options.enableCrashHandler else {
                SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
                return nil
            }

            self.options = options
            super.init()

            // This config overrides KSCrashConfiguration defaults in order
            // to align with how SentryCrash was configured
            let config = KSCrashConfiguration()
            config.monitors = [
                .machException,
                .signal,
                .cppException,
                .nsException,
                .applicationState
            ]
            config.enableMemoryIntrospection = true
            config.installPath = options.cacheDirectoryPath
            config.reportStoreConfiguration.maxReportCount = 5
            config.reportStoreConfiguration.reportCleanupPolicy = .always

            do {
                try dependencies.ksCrashInstaller.install(with: config)
            } catch {
                SentrySDKLog.error("Failed to install KSCrash: \(error)")
                return nil
            }

            SentrySDKInternal.crashReporterInstalled = true
        }

        // MARK: - SwiftIntegration
        static var name: String {
            "SentryKSCrashIntegration"
        }

        func uninstall() {}
    }
}

#endif
