#if ENABLE_KSCRASH
/// Abstraction over `KSCrash.shared` to keep `SentryKSCrashIntegration` testable without
/// linking KSCrash into every target that tests it.
@_spi(Private) public protocol KSCrashInstalling {
    /// Install the crash handler.
    /// - Parameters:
    ///   - installPath: The base directory for crash report storage.
    ///   - monitors: Raw monitor type bitmask (maps to `KSCrashMonitorType`).
    ///   - enableSwapCxaThrow: Whether to swap `__cxa_throw` for better C++ stacks.
    /// - Throws: Any error from `KSCrash.installWithConfiguration(_:error:)`.
    func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws

    /// Whether the previous run crashed.
    var crashedLastLaunch: Bool { get }
}

/// Provides a `KSCrashInstalling` instance for dependency injection.
@_spi(Private) public protocol KSCrashInstallerProvider {
    /// The installer used to set up KSCrash crash reporting.
    var kscrashInstaller: any KSCrashInstalling { get }
}
#endif
