#if ENABLE_KSCRASH
internal import KSCrashRecording

/// A service that installs the KSCrash system.
protocol SentryKSCrashInstalling {
    /// Installs the KSCrash system with the given configuration.
    /// - Parameters:
    ///   - configuration: The configuration to use for the KSCrash system.
    /// - Throws: An error if the KSCrash system cannot be installed.
    func install(with configuration: KSCrashConfiguration) throws
}

extension SentryKSCrash {
    /// Default KSCrash installer
    struct CrashInstaller: SentryKSCrashInstalling {
        func install(with configuration: KSCrashConfiguration) throws {
            try KSCrash.shared.install(with: configuration)
        }
    }
}
#endif
