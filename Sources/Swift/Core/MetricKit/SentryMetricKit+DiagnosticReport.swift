#if canImport(MetricKit) && !os(tvOS)
extension SentryMetricKit {
    /// A MetricKit diagnostic report the SDK can capture as an event.
    ///
    /// Used by ``SentryMetricKitOptions/enabledDiagnosticReports`` to choose which reports to capture.
    public enum DiagnosticReport: Hashable, CaseIterable, Sendable {
        /// A crash of the app, reported by `MXCrashDiagnostic`.
        ///
        /// The SDK drops MetricKit crashes of runs its crash handler already reported, so this
        /// report adds the crashes the crash handler couldn't record.
        ///
        /// - Warning: MetricKit only reports which process crashed on iOS 17, macOS 14 and
        ///   visionOS and later. On earlier versions the SDK can't tell whether the crash handler
        ///   already reported a crash, so the same crash can show up twice.
        case crash

        /// A hang of the main thread, reported by `MXHangDiagnostic`.
        case hang

        /// A CPU usage exception, reported by `MXCPUExceptionDiagnostic`.
        case cpuException

        /// A disk write exception, reported by `MXDiskWriteExceptionDiagnostic`.
        case diskWriteException

        /// A slow app launch, reported by `MXAppLaunchDiagnostic`.
        ///
        /// - Note: MetricKit reports app launch diagnostics on iOS 16 and later, on visionOS 26
        ///   and earlier, and on macOS 27 and later.
        case appLaunch

        /// A termination of the app or an extension for exceeding its memory limit, reported by
        /// `MemoryExceptionDiagnostic`.
        ///
        /// - Note: MetricKit only reports memory exception diagnostics on iOS 27 and later.
        /// - Warning: The SDK's watchdog termination tracking already reports out-of-memory
        ///   terminations. Enabling this report sends the terminations MetricKit reports in
        ///   addition, so the same termination can show up twice, unless
        ///   ``SentryMetricKitOptions/enrichWatchdogTerminations`` adds the diagnostic to the
        ///   watchdog termination event instead.
        case memoryException
    }
}

extension SentryMetricKit.DiagnosticReport {
    var exceptionType: String {
        switch self {
        case .crash:
            return "MXCrashDiagnostic"
        case .diskWriteException:
            return "MXDiskWriteException"
        case .cpuException:
            return "MXCPUException"
        case .hang:
            return "MXHangDiagnostic"
        case .appLaunch:
            return "MXAppLaunchDiagnostic"
        case .memoryException:
            return "MXMemoryException"
        }
    }

    var mechanism: String {
        switch self {
        case .crash:
            return "MXCrashDiagnostic"
        case .diskWriteException:
            return "mx_disk_write_exception"
        case .cpuException:
            return "mx_cpu_exception"
        case .hang:
            return "mx_hang_diagnostic"
        case .appLaunch:
            return "mx_app_launch_diagnostic"
        case .memoryException:
            return "mx_memory_exception"
        }
    }

    /// Crashes and memory exceptions terminate the app, the other reports don't.
    var isHandled: Bool {
        switch self {
        case .crash, .memoryException:
            return false
        case .hang, .cpuException, .diskWriteException, .appLaunch:
            return true
        }
    }

    static var all: Set<Self> {
        .init(allCases)
    }

    /// Creates a report from its name in the options dictionary hybrid SDKs use.
    init?(dictionaryValue: String) {
        switch dictionaryValue {
        case "crash":
            self = .crash
        case "hang":
            self = .hang
        case "cpuException":
            self = .cpuException
        case "diskWriteException":
            self = .diskWriteException
        case "appLaunch":
            self = .appLaunch
        case "memoryException":
            self = .memoryException
        default:
            return nil
        }
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
