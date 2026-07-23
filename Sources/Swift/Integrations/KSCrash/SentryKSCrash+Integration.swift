#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
@_implementationOnly import KSCrashInstallations
import Foundation

// MARK: - Integration
extension SentryKSCrash {
    typealias DependencyProvider = SentryKSCrash.InstallerProvider

    /// Crash detectors matching SentryCrash's production monitor set:
    /// Mach exceptions, signals, C++ exceptions, and NSExceptions.
    /// KSCrash unconditionally adds its Required monitors (System, AppState,
    /// UserInfo, Resource) on top of whatever is passed here.
    static let productionSafeMonitors: UInt = MonitorType([
        .machException,
        .signal,
        .cppException,
        .nsException
    ]).rawValue

    final class Integration<Dependencies: DependencyProvider>: NSObject, SwiftIntegration {
        private weak var options: Options?

        // MARK: - Initialization

        init?(with options: Options, dependencies: Dependencies) {
            guard options.enableCrashHandler else {
                SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
                return nil
            }

            self.options = options
            super.init()

            // To match KSCrash & SentryCrash, we need to add 'KSCrash/<bundlename>' to the cacheDirectoryPath
            let installPath = URL(fileURLWithPath: options.cacheDirectoryPath)
                .appendingPathComponent("KSCrash")
                .appendingPathComponent(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown")
                .absoluteURL

            do {
                try dependencies.kscrashInstaller.install(
                    installPath: installPath.path,
                    monitors: productionSafeMonitors,
                    enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2
                )
            } catch {
                SentrySDKLog.error("KSCrash install failed: \(error)")
                return nil
            }

            SentrySDKInternal.crashReporterInstalled = true
            if dependencies.kscrashInstaller.crashedLastLaunch {
                SentrySDKInternal.fatalDetected = true
                SentrySDKInternal.crashHandlerDetectedCrash = true
            }
        }

        // MARK: - SwiftIntegration
        static var name: String {
            "SentryKSCrashIntegration"
        }

        func uninstall() {}
    }
}
#endif
