#if ENABLE_KSCRASH
import Foundation

extension SentryKSCrash {
    /// Sentry-owned description of how the KSCrash system should be installed.
    ///
    /// This mirrors the subset of `KSCrashConfiguration` that Sentry configures, but
    /// deliberately uses only Sentry types so that `KSCrashRecording` never leaks into
    /// Sentry's `@testable` interface. The default installer
    /// (`SentryKSCrash.CrashInstaller`) is the only place that translates this into a
    /// real `KSCrashConfiguration`, keeping the KSCrash package out of every test target.
    struct Configuration: Equatable {
        var monitors: MonitorType = []
        var enableMemoryIntrospection = false
        var installPath: String?
        var maxReportCount = 0
        var reportCleanupPolicy: ReportCleanupPolicy = .always
    }

    /// The crash monitors Sentry enables, mirroring `KSCrashMonitorType`.
    struct MonitorType: OptionSet {
        let rawValue: UInt

        static let machException = MonitorType(rawValue: 1 << 0)
        static let signal = MonitorType(rawValue: 1 << 1)
        static let cppException = MonitorType(rawValue: 1 << 2)
        static let nsException = MonitorType(rawValue: 1 << 3)
        static let applicationState = MonitorType(rawValue: 1 << 7)
    }

    /// When KSCrash removes persisted reports, mirroring `KSCrashReportCleanupPolicy`.
    enum ReportCleanupPolicy {
        case never
        case onSuccess
        case always
    }
}

/// Convenience alias so call sites can use `SentryKSCrashConfiguration` directly.
typealias SentryKSCrashConfiguration = SentryKSCrash.Configuration
#endif
