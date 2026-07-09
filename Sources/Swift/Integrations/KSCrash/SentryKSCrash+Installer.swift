#if ENABLE_KSCRASH
// Implementation-only so `KSCrashRecording` stays out of Sentry's `@testable`
// interface. Only this file references KSCrash types, and only inside method bodies,
// which keeps the KSCrash package from being linked into any test target.
@_implementationOnly import KSCrashRecording

/// A service that installs the KSCrash system.
protocol SentryKSCrashInstalling {
    /// Installs the KSCrash system with the given configuration.
    /// - Parameters:
    ///   - configuration: The configuration to use for the KSCrash system.
    /// - Throws: An error if the KSCrash system cannot be installed.
    func install(with configuration: SentryKSCrashConfiguration) throws
}

extension SentryKSCrash {
    /// Default KSCrash installer
    struct CrashInstaller: SentryKSCrashInstalling {
        func install(with configuration: SentryKSCrashConfiguration) throws {
            try KSCrash.shared.install(with: Self.ksCrashConfiguration(from: configuration))
        }

        /// Translates the Sentry-owned configuration into a `KSCrashConfiguration`.
        private static func ksCrashConfiguration(from configuration: SentryKSCrashConfiguration) -> KSCrashConfiguration {
            let config = KSCrashConfiguration()
            config.monitors = ksCrashMonitors(from: configuration.monitors)
            config.enableMemoryIntrospection = configuration.enableMemoryIntrospection
            config.installPath = configuration.installPath
            config.reportStoreConfiguration.maxReportCount = configuration.maxReportCount
            config.reportStoreConfiguration.reportCleanupPolicy = ksCrashCleanupPolicy(from: configuration.reportCleanupPolicy)
            return config
        }

        private static func ksCrashMonitors(from monitors: SentryKSCrash.MonitorType) -> KSCrashRecording.MonitorType {
            // `KSCrashRecording.` qualifies KSCrash's `MonitorType`, disambiguating it
            // from `SentryKSCrash.MonitorType` inside this extension.
            var result: KSCrashRecording.MonitorType = []
            if monitors.contains(.machException) { result.insert(.machException) }
            if monitors.contains(.signal) { result.insert(.signal) }
            if monitors.contains(.cppException) { result.insert(.cppException) }
            if monitors.contains(.nsException) { result.insert(.nsException) }
            if monitors.contains(.applicationState) { result.insert(.applicationState) }
            return result
        }

        private static func ksCrashCleanupPolicy(from policy: SentryKSCrash.ReportCleanupPolicy) -> KSCrashRecording.CrashReportCleanupPolicy {
            switch policy {
            case .never: return .never
            case .onSuccess: return .onSuccess
            case .always: return .always
            }
        }
    }
}
#endif
