#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import KSCrashInstallations

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    let kscrashInstaller: MockKSCrashInstaller

    init(installer: MockKSCrashInstaller = .init()) {
        self.kscrashInstaller = installer
    }
}

final class MockKSCrashInstaller: SentryKSCrash.Installing {
    public var installCalls: [(installPath: String, monitors: MonitorType, enableSwapCxaThrow: Bool)] = []
    public var shouldThrow: Error?
    public var crashedLastLaunch: Bool = false

    public init() {}

    public func install(installPath: String, monitors: MonitorType, enableSwapCxaThrow: Bool) throws {
        installCalls.append((installPath: installPath, monitors: monitors, enableSwapCxaThrow: enableSwapCxaThrow))
        if let error = shouldThrow { throw error }
    }
}
#endif
