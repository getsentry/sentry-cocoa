#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
@_implementationOnly import KSCrashInstallations
import Foundation

// MARK: - Dependency Provider

/// Provides dependencies for `SentryKSCrashIntegration`.
typealias KSCrashIntegrationProvider = KSCrashInstallerProvider

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

        do {
            try dependencies.kscrashInstaller.install(
                installPath: options.cacheDirectoryPath,
                monitors: kscrashProductionSafeMonitors, // TODO: match this with SentryCrash's existing monitors
                enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2
            )
        } catch {
            SentrySDKLog.error("KSCrash install failed: \(error)")
            return nil
        }

        SentrySDKInternal.crashReporterInstalled = true
        if dependencies.kscrashInstaller.crashedLastLaunch {
            SentrySDKInternal.fatalDetected = true
        }
    }

    // MARK: - SwiftIntegration
    static var name: String {
        "SentryKSCrashIntegration"
    }

    func uninstall() {}
}
#endif
