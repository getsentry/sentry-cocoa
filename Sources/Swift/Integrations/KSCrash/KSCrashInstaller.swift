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
        try KSCrash.shared.install(with: config)
    }

    var crashedLastLaunch: Bool { KSCrash.shared.crashedLastLaunch }
}
#endif
