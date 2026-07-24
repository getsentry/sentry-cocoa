#if ENABLE_KSCRASH
internal import KSCrashInstallations

extension SentryKSCrash {
    protocol Installing {
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

    /// Configures and installs a crash handler
    struct Installer: SentryKSCrash.Installing {
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
}
#endif
