#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations
internal import _SentryPrivate

extension SentryKSCrash {
    protocol Installing {
        /// Install the crash handler.
        /// - Parameters:
        ///   - installPath: The base directory for crash report storage.
        ///   - monitors: Monitor types to enable.
        ///   - enableSwapCxaThrow: Whether to swap `__cxa_throw` for better C++ stacks.
        /// - Throws: Any error from `KSCrash.installWithConfiguration(_:error:)`.
        func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws

        /// Processes all reports recorded during previous runs.
        func sendAllReports(reportProcessor: SentryCrashReportProcessor)

        /// Whether the previous run crashed.
        var crashedLastLaunch: Bool { get }
    }

    /// Configures and installs a crash handler
    struct Installer: SentryKSCrash.Installing {
        func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws {
            let config = KSCrashConfiguration()
            config.installPath = installPath
            config.monitors = MonitorType(rawValue: monitors)
            config.enableSwapCxaThrow = enableSwapCxaThrow
            config.reportStoreConfiguration.reportCleanupPolicy = .onSuccess
            do {
                try KSCrash.shared.install(with: config)
            } catch let error as NSError
                        where error.domain == "KSCrashErrorDomain" && error.code == 1 /* KSCrashInstallErrorAlreadyInstalled */ {
                // KSCrash holds a process-lifetime C flag, so install() fails on every
                // subsequent call within the same process (common during tests and SDK re-init).
                // The crash handler is already running — treat this as success.
                SentrySDKLog.debug("KSCrash already installed; continuing.")
            }
        }

        func sendAllReports(reportProcessor: SentryCrashReportProcessor) {
            guard let reportStore = KSCrash.shared.reportStore else {
                SentrySDKLog.error("KSCrash report store is unavailable; retaining crash reports.")
                return
            }

            reportStore.sink = SentryKSCrash.ReportFilter(reportProcessor: reportProcessor)
            reportStore.reportCleanupPolicy = .onSuccess
            reportStore.sendAllReports { filteredReports, error in
                if let error = error {
                    SentrySDKLog.error("Error processing KSCrash reports: \(error.localizedDescription)")
                } else {
                    SentrySDKLog.debug("Processed \(filteredReports?.count ?? 0) KSCrash report(s)")
                }
            }
        }

        var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
    }
}
#endif
