#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations
internal import _SentryPrivate
import Foundation

// MARK: - Integration
extension SentryKSCrash {
    typealias DependencyProvider = SentryKSCrash.InstallerProvider & DateProviderProvider & DispatchQueueWrapperProvider & FileManagerProvider

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

            // KSCRASH_TODO: Preserve SentryCrashIntegration's macOS AppKit NSException forwarding.
            // SentryUncaughtNSExceptions currently routes reportException:/_crashOnException:
            // through SentryNSExceptionCaptureHelper to SentryCrashSwift. Replace that direct
            // dependency with an active-backend facade and supply KSCrash's uncaughtExceptionHandler.
            // The reporter-neutral macOS CrashE2E ns-exception scenario is the acceptance test.
            // Tracked in https://github.com/getsentry/sentry-cocoa/issues/8529.

            // KSCRASH_TODO: Restore previous-run session handling for watchdog terminations and
            // fatal app hangs through reporter-neutral coordination. It must run before automatic
            // session tracking and the corresponding event processing.
            // Tracked in https://github.com/getsentry/sentry-cocoa/issues/8674.
            if installer.crashedLastLaunch {
                SentrySDKInternal.fatalDetected = true

                // Persist the previous session before report processing or auto session tracking
                // can start, so the first fatal event can attach the crashed session.
                endPreviousSessionAsCrashed(
                    activeDurationSinceLastCrash: installer.activeDurationSinceLastCrash,
                    dependencies: dependencies
                )
            }

            let reportProcessor = SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
                currentHubProvider: { SentrySDKInternal.currentHub() },
                preserveCrashedSessionOnCaptureFailure: true
            )
            // The report filter dispatches regular reports itself. Keep this call synchronous so
            // startup crashes can be captured and flushed before SDK initialization returns.
            installer.sendAllReports(
                reportProcessor: reportProcessor,
                dispatchQueue: dependencies.dispatchQueueWrapper
            )
        }

        private func endPreviousSessionAsCrashed(
            activeDurationSinceLastCrash: TimeInterval,
            dependencies: Dependencies
        ) {
            guard let fileManager = dependencies.fileManager else {
                SentrySDKLog.warning("File manager is unavailable; cannot persist the crashed session.")
                return
            }
            guard let session = fileManager.readCurrentSession() else {
                SentrySDKLog.debug("No current session found to end as crashed.")
                return
            }

            let crashTimestamp = dependencies.dateProvider.date()
                .addingTimeInterval(-activeDurationSinceLastCrash)
            session.endCrashed(withTimestamp: crashTimestamp)
            fileManager.storeCrashedSession(session)
            fileManager.deleteCurrentSession()
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
