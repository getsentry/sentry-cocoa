#if SDK_V10
internal import _SentryPrivate
internal import KSCrashRecording
import Foundation

extension SentryKSCrash {
    protocol Installing {
        /// Install the crash handler.
        /// - Parameters:
        ///   - installPath: The base directory for crash report storage.
        ///   - monitors: Monitor types to enable.
        ///   - enableMemoryIntrospection: Whether to introspect memory contents during a crash.
        ///   - enableSwapCxaThrow: Whether to swap `__cxa_throw` for better C++ stacks.
        /// - Throws: Any error from `KSCrash.installWithConfiguration(_:error:)`.
        func install(
            installPath: String,
            monitors: UInt,
            enableMemoryIntrospection: Bool,
            enableSwapCxaThrow: Bool
        ) throws

        /// Uninstall the crash handler for the current SDK lifecycle.
        func uninstall()

        /// Processes all reports recorded during previous runs.
        func sendAllReports(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper,
            processingSession: ReportProcessingSession
        )

        /// Whether the previous run crashed.
        var crashedLastLaunch: Bool { get }

        /// Whether this installer has successfully installed for the current SDK lifecycle.
        ///
        /// Tracked separately from KSCrash's process-lifetime `reportStore`, which stays
        /// non-nil after `SentrySDK.close()`.
        var installed: Bool { get }

        /// Total active time elapsed since the previous crash.
        var activeDurationSinceLastCrash: TimeInterval { get }

        /// Adds additional user information to the crash handler
        func setUserInfo(_ userInfo: [String: Any])
    }

    /// Configures and installs a crash handler.
    final class Installer: SentryKSCrash.Installing {
        private static let startupCrashFlushDuration: TimeInterval = 5

        private(set) var installed = false

        func install(
            installPath: String,
            monitors: UInt,
            enableMemoryIntrospection: Bool,
            enableSwapCxaThrow: Bool
        ) throws {
            let config = KSCrashConfiguration()
            config.installPath = installPath
            config.monitors = MonitorType(rawValue: monitors)
            config.enableMemoryIntrospection = enableMemoryIntrospection
            config.enableSwapCxaThrow = enableSwapCxaThrow
            config.reportStoreConfiguration.reportCleanupPolicy = .onSuccess
            #if SENTRY_CRASH_E2E
            config.userInfoJSON = SentryKSCrash.CrashE2ETestHook.reportUserInfo
            #endif
            do {
                try KSCrash.shared.install(with: config)
            } catch let error as NSError
                        where error.domain == "KSCrashErrorDomain" && error.code == 1 /* KSCrashInstallErrorAlreadyInstalled */ {
                // KSCrash holds a process-lifetime C flag, so install() fails on every
                // subsequent call within the same process (common during tests and SDK re-init).
                // The crash handler is already running — treat this as success.
                SentrySDKLog.debug("KSCrash already installed; continuing.")
            }
            installed = true
        }

        func uninstall() {
            // KSCrash itself cannot be uninstalled in-process (process-lifetime).
            installed = false
        }

        func sendAllReports(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper,
            processingSession: ReportProcessingSession
        ) {
            guard let reportStore = KSCrash.shared.reportStore else {
                SentrySDKLog.error("KSCrash report store is unavailable; retaining crash reports.")
                return
            }

            reportStore.sink = SentryKSCrash.ReportFilter(
                reportProcessor: reportProcessor,
                dispatchQueue: dispatchQueue,
                processingSession: processingSession
            )
            reportStore.reportCleanupPolicy = .onSuccess

            // Delivery policy:
            // - KSCrash applies .onSuccess cleanup to an entire send invocation.
            // - ReportFilterCore returns nil errors for captured or permanently invalid reports,
            //   allowing KSCrash to delete them.
            // - ReportFilterCore returns retryable errors for reports that must remain on disk.
            // Send one report per invocation so those decisions never retain an already captured
            // report, then continue with the remaining report IDs regardless of each result while
            // this integration's processing session remains active.
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
                    #if SENTRY_CRASH_E2E
                    SentryKSCrash.CrashE2ETestHook.markReportProcessingComplete()
                    #endif
                },
                processingSession: processingSession
            )
            reportStoreSender.sendAllReports(
                reportStore.reportIDs.map { $0.int64Value },
                // Process startup crashes before regular reports can move delivery off-thread.
                prioritizing: { reportID in
                    guard let report = reportStore.report(for: reportID) else {
                        return false
                    }
                    return SentryKSCrash.ReportFilterCore.isStartupCrash(report.value)
                },
                // Flush the completed startup phase once before regular delivery begins.
                onPrioritizedReportsCompleted: {
                    SentrySDKInternal.flush(timeout: Self.startupCrashFlushDuration)
                }
            )
        }

        var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
        var activeDurationSinceLastCrash: TimeInterval { KSCrash.shared.activeDurationSinceLastCrash }

        // KSCRASH_TODO(GH-8756): We need to support dictionary types here... KSCrash's new KV store
        // doesn't support them... we will need to either: work around this OR
        // upstream support for it.
        // Tracked in https://github.com/getsentry/sentry-cocoa/issues/8756
        func setUserInfo(_ userInfo: [String: Any]) {
            guard installed else {
                SentrySDKLog.debug("KSCrash must be installed before calling setUserInfo(_:)")
                return
            }

            for (key, value) in userInfo {
                switch value {
                case let value as String:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                case let value as Int:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                case let value as UInt:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                case let value as Double:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                case let value as Bool:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                case let value as Date:
                    KSCrash.shared.setUserInfo(value, forKey: key)
                default:
                    SentrySDKLog.debug("Dropping '\(key): \(value) as it's not a supported type")
                }
            }
        }
    }
}
#endif
