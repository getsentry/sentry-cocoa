#if SDK_V10
internal import _SentryPrivate
internal import KSCrashRecording
import Foundation

// MARK: - Integration
extension SentryKSCrash {
    typealias DependencyProvider = SentryKSCrash.InstallerProvider & DateProviderProvider & DispatchQueueWrapperProvider & FileManagerProvider

    /// Crash detectors matching SentryCrash's production monitor set:
    /// Mach exceptions, signals, C++ exceptions, and NSExceptions.
    /// KSCrash unconditionally adds its required infrastructure monitors on top of
    /// the crash detectors passed here.
    static let productionSafeMonitors: MonitorType = [
        .machException,
        .signal,
        .cppException,
        .nsException
    ]

    final class Integration<Dependencies: DependencyProvider>: NSObject, SwiftIntegration {
        private weak var options: Options?
        private let installer: Dependencies.Installing
        private let reportProcessingSession = ReportProcessingSession()
        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        private let nsExceptionHandlerOwner = NSObject()
        #endif

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
                    enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2,
                    enableSwiftAsyncStackTraces: options.swiftAsyncStacktraces
                )
            } catch {
                SentrySDKLog.error("KSCrash install failed: \(error)")
                return nil
            }

            #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
            SentryNSExceptionCaptureHelper.setUncaughtExceptionHandler(
                installer.uncaughtExceptionHandler,
                owner: nsExceptionHandlerOwner
            )
            if options.enableSwizzling && options.enableUncaughtNSExceptionReporting {
                SentryUncaughtNSExceptions.configureCrashOnExceptions()
                SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
                SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()
            }
            #endif

#if SENTRY_DISABLE_SENTRYCRASH_V10
            // KSCRASH_TODO(GH-8276): V10 does not retain SentryKSCrash.Scope.Configuration, so its
            // observer is not installed in production. Acceptance: SCV10-013 in
            // SENTRYCRASH_V10_MIGRATION_LEDGER.md.
            // KSCRASH_TODO(GH-8276, GH-8756): V10 does not populate initial crash user info through
            // the inactive scope configuration. Acceptance: SCV10-015 in the migration ledger.
            // KSCRASH_TODO(GH-8736): V10 does not install the inactive configuration's low-power
            // scope observer. Acceptance: SCV10-026 in the migration ledger.
            // KSCRASH_TODO(GH-8674): V10 handles actual crashes below but omits previous-run
            // watchdog and fatal-app-hang session finalization. Acceptance: SCV10-025 in the ledger.
            // KSCRASH_TODO(GH-8735): V10 does not register a callback to persist an active trace
            // when crashing. Acceptance: SCV10-027 in the migration ledger.
            // KSCRASH_TODO(GH-8797): V10 has no early KSCrash signal preloader, so managed-runtime
            // handler ordering is not preserved. Acceptance: SCV10-033 in the migration ledger.
            // KSCRASH_TODO(GH-8652): V10 intentionally ignores enableSigtermReporting while its
            // public API removal is pending. Acceptance: SCV10-031 in the migration ledger.
#endif

            if installer.crashedLastLaunch {
                SentrySDKInternal.fatalDetected = true

                // Persist the previous session before report processing or auto session tracking
                // can start, so the first fatal event can attach the crashed session.
                endPreviousSessionAsCrashed(
                    activeDurationSinceLastCrash: installer.activeDurationSinceLastCrash,
                    dependencies: dependencies
                )
            }

            processStoredReports(options: options, dependencies: dependencies)
        }

        private func processStoredReports(options: Options, dependencies: Dependencies) {
            let reportProcessor = SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes),
                currentHubProvider: { SentrySDKInternal.currentHub() },
                preserveCrashedSessionOnCaptureFailure: true
            )
            // The report filter dispatches regular reports itself. Keep this call synchronous so
            // startup crashes can be captured and flushed before SDK initialization returns.
            installer.sendAllReports(
                reportProcessor: reportProcessor,
                dispatchQueue: dependencies.dispatchQueueWrapper,
                processingSession: reportProcessingSession
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
#if SENTRY_DISABLE_SENTRYCRASH_V10
            // KSCRASH_TODO(GH-8536): V10 cancels report processing and updates query state, but the
            // process-lifetime KSCrash recorder remains active. Acceptance: SCV10-032 in
            // SENTRYCRASH_V10_MIGRATION_LEDGER.md.
#endif
            reportProcessingSession.cancel()
            #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
            SentryNSExceptionCaptureHelper.clearUncaughtExceptionHandler(forOwner: nsExceptionHandlerOwner)
            #endif
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
