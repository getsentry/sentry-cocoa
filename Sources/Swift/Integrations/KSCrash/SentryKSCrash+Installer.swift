#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashRecording
internal import _SentryPrivate
import Foundation

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
        func sendAllReports(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper
        )

        /// Whether the previous run crashed.
        var crashedLastLaunch: Bool { get }

        /// Total active time elapsed since the previous crash.
        var activeDurationSinceLastCrash: TimeInterval { get }
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

        func sendAllReports(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper
        ) {
            guard let reportStore = KSCrash.shared.reportStore else {
                SentrySDKLog.error("KSCrash report store is unavailable; retaining crash reports.")
                return
            }

            reportStore.sink = SentryKSCrash.ReportFilter(
                reportProcessor: reportProcessor,
                dispatchQueue: dispatchQueue
            )
            reportStore.reportCleanupPolicy = .onSuccess

            // Delivery policy:
            // - KSCrash applies .onSuccess cleanup to an entire send invocation.
            // - ReportFilterCore returns nil errors for captured or permanently invalid reports,
            //   allowing KSCrash to delete them.
            // - ReportFilterCore returns retryable errors for reports that must remain on disk.
            // Send one report per invocation so those decisions never retain an already captured
            // report, then continue with the remaining report IDs regardless of each result.
            let reportStoreSender = SentryKSCrash.ReportStoreSender(
                sendReport: { reportID, onCompletion in
                    reportStore.sendReport(
                        withID: reportID,
                        includeCurrentRun: false
                    ) { filteredReports, error in
                        onCompletion(filteredReports?.count ?? 0, error)
                    }
                },
                cleanupOrphanedRunSidecars: {
                    reportStore.cleanupOrphanedRunSidecars()
                }
            )
            reportStoreSender.sendAllReports(
                reportStore.reportIDs.map { $0.int64Value },
                // Process startup crashes before regular reports can move delivery off-thread.
                prioritizing: { reportID in
                    guard let report = reportStore.report(for: reportID) else {
                        return false
                    }
                    return SentryKSCrash.ReportFilterCore.isStartupCrash(report.value)
                }
            )
        }

        var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
        var activeDurationSinceLastCrash: TimeInterval { KSCrash.shared.activeDurationSinceLastCrash }
    }
}
#endif
