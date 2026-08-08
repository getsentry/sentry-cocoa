#if SDK_V10
/// All types related to KSCrash should live under this type
@_spi(Private) public enum SentryKSCrash {
    /// Provides a `KSCrashInstalling` instance for dependency injection.
    protocol InstallerProvider {
        /// The installer used to set up KSCrash crash reporting.
        associatedtype Installing: SentryKSCrash.Installing

        func getKSCrashInstaller() -> Installing
    }
}
#endif
