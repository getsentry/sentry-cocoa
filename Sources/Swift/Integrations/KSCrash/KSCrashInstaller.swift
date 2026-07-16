#if ENABLE_KSCRASH
@_implementationOnly import KSCrashInstallations

/// Abstraction over `KSCrash.shared` to keep `SentryKSCrashIntegration` testable without
/// linking KSCrash into every target that tests it.
 protocol KSCrashInstalling {
    /// Install the crash handler.
    /// - Parameters:
    ///   - installPath: The base directory for crash report storage.
    ///   - monitors: Monitor types to enable.
    ///   - enableSwapCxaThrow: Whether to swap `__cxa_throw` for better C++ stacks.
    /// - Throws: Any error from `KSCrash.installWithConfiguration(_:error:)`.
     func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws

    /// Whether the previous run crashed.
    var crashedLastLaunch: Bool { get }
}

/// Provides a `KSCrashInstalling` instance for dependency injection.
protocol KSCrashInstallerProvider {
    /// The installer used to set up KSCrash crash reporting.
    var kscrashInstaller: any KSCrashInstalling { get }
}

/// The production-safe monitor set passed to KSCrash on install.
/// Exposed as a primitive so test targets can assert against it without importing KSCrash.
let kscrashProductionSafeMonitors: UInt = MonitorType.productionSafeMinimal.rawValue

/// Wraps `KSCrash.shared` for production use.
struct KSCrashInstaller: KSCrashInstalling {
    func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws {
        let config = KSCrashConfiguration()
        config.installPath = installPath
        config.monitors = MonitorType(rawValue: monitors)
        config.enableSwapCxaThrow = enableSwapCxaThrow
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

    var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
}
#endif
