#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
@_implementationOnly import KSCrashInstallations
import Foundation

// MARK: - Integration
extension SentryKSCrash {
    typealias DependencyProvider = SentryKSCrash.InstallerProvider & DispatchQueueWrapperProvider

    /// Crash detectors matching SentryCrash's production monitor set:
    /// Mach exceptions, signals, C++ exceptions, and NSExceptions.
    /// Required infrastructure monitors are explicit because KSCrash 2.6.0-beta.3
    /// does not add them to its registered monitor set when given a custom mask.
    static let productionSafeMonitors: UInt = MonitorType([
        .machException,
        .signal,
        .cppException,
        .nsException,
        .required
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
            let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
            let installPath = URL(fileURLWithPath: options.cacheDirectoryPath)
                .appendingPathComponent("KSCrash")
                .appendingPathComponent(bundleName.replacingOccurrences(of: "/", with: "-"))
                .absoluteURL

            let installer = dependencies.kscrashInstaller
            do {
                try installer.install(
                    installPath: installPath.path,
                    monitors: productionSafeMonitors,
                    enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2
                )
            } catch {
                SentrySDKLog.error("KSCrash install failed: \(error)")
                return nil
            }

            SentrySDKInternal.crashReporterInstalled = true
            if installer.crashedLastLaunch {
                SentrySDKInternal.fatalDetected = true
                SentrySDKInternal.crashHandlerDetectedCrash = true
            }

            let reportProcessor = SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes)
            )
            dependencies.dispatchQueueWrapper.dispatchAsync {
                installer.sendAllReports(reportProcessor: reportProcessor)
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
