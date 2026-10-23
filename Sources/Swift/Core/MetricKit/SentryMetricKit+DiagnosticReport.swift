#if canImport(MetricKit) && !os(tvOS)
extension SentryMetricKit {
    /// A MetricKit diagnostic report the SDK can capture as an event.
    ///
    /// Used by ``SentryMetricKitOptions/enabledDiagnosticReports`` to choose which reports to capture.
    public enum DiagnosticReport: Hashable, CaseIterable, Sendable {
        /// A crash of the app, reported by `MXCrashDiagnostic`.
        ///
        /// - Warning: The SDK's crash handler already reports crashes. Enabling this report sends
        ///   the crashes MetricKit reports in addition, so the same crash can show up twice.
        case crash

        /// A hang of the main thread, reported by `MXHangDiagnostic`.
        case hang

        /// A CPU usage exception, reported by `MXCPUExceptionDiagnostic`.
        case cpuException

        /// A disk write exception, reported by `MXDiskWriteExceptionDiagnostic`.
        case diskWriteException

        /// A slow app launch, reported by `MXAppLaunchDiagnostic`.
        ///
        /// - Note: MetricKit only reports app launch diagnostics on iOS 16 and later and on visionOS.
        case appLaunch
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
        }
    }

    static var all: Set<Self> {
        .init(allCases)
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
