#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations
internal import _SentryPrivate
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
        private let installer: Dependencies.Installing

        // MARK: - Initialization

        init?(with options: Options, dependencies: Dependencies) {
            guard options.enableCrashHandler else {
                SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
                return nil
            }

            self.options = options
            let installer = dependencies.getKSCrashInstaller()
            self.installer = installer
            super.init()

            // To match KSCrash & SentryCrash, we need to add 'KSCrash/<bundlename>' to the cacheDirectoryPath
            let installPath = Self.installPath(for: options.cacheDirectoryPath, bundleInfo: Bundle.main.infoDictionary)

            do {
                try installer.install(
                    installPath: installPath.path,
                    monitors: productionSafeMonitors,
                    enableMemoryIntrospection: options.enableMemoryIntrospection,
                    enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2
                )
            } catch {
                SentrySDKLog.error("KSCrash install failed: \(error)")
                return nil
            }

            if installer.crashedLastLaunch {
                SentrySDKInternal.fatalDetected = true
            }
        }

        // MARK: - SwiftIntegration
        static var name: String {
            "SentryKSCrashIntegration"
        }

        func uninstall() {
            installer.uninstall()
        }

        // MARK: - Helpers
        /// Get the install path for the crash reporter
        /// This method exists to centralize path building to save rebuilding it manually in tests
        static func installPath(for cacheDirectoryPath: String, bundleInfo: [String: Any]?) -> URL {
            let bundleName = bundleInfo?["CFBundleName"] as? String ?? "Unknown"
            return URL(fileURLWithPath: cacheDirectoryPath)
                .appendingPathComponent("KSCrash")
                .appendingPathComponent(bundleName.replacingOccurrences(of: "/", with: "-"))
                .absoluteURL
        }
    }
}
#endif
