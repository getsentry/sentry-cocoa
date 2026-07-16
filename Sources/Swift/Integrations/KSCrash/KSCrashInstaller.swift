#if ENABLE_KSCRASH
@_implementationOnly import KSCrashInstallations

/// The production-safe monitor set passed to KSCrash on install.
/// Exposed as a primitive so test targets can assert against it without importing KSCrash.
@_spi(Private) public let kscrashProductionSafeMonitors: UInt = MonitorType.productionSafeMinimal.rawValue

/// Wraps `KSCrash.shared` for production use.
final class KSCrashInstaller: KSCrashInstalling {
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
