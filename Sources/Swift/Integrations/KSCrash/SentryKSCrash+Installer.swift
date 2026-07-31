#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations

extension SentryKSCrash {
    protocol Installing {
        /// Install the crash handler.
        /// - Parameters:
        ///   - installPath: The base directory for crash report storage.
        ///   - monitors: Monitor types to enable.
        ///   - enableSwapCxaThrow: Whether to swap `__cxa_throw` for better C++ stacks.
        /// - Throws: Any error from `KSCrash.installWithConfiguration(_:error:)`.
        func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws

        /// Uninstall the crash handler for the current SDK lifecycle.
        func uninstall()

        /// Whether the previous run crashed.
        var crashedLastLaunch: Bool { get }

        /// Whether this installer has successfully installed for the current SDK lifecycle.
        ///
        /// Tracked separately from KSCrash's process-lifetime `reportStore`, which stays
        /// non-nil after `SentrySDK.close()`.
        var installed: Bool { get }
    }

    /// Configures and installs a crash handler.
    final class Installer: SentryKSCrash.Installing {
        private(set) var installed = false

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
            installed = true
        }

        func uninstall() {
            // KSCrash itself cannot be uninstalled in-process (process-lifetime).
            installed = false
        }

        var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
    }
}
#endif
