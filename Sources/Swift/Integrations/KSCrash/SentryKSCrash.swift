#if ENABLE_KSCRASH
/// All types related to KSCrash should live under this type
enum SentryKSCrash {
    /// Provides a `KSCrashInstalling` instance for dependency injection.
    protocol InstallerProvider {
        /// The installer used to set up KSCrash crash reporting.
        associatedtype Installing: SentryKSCrash.Installing

        var kscrashInstaller: Installing { get }
    }
}
#endif
