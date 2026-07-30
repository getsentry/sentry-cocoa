#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry

final class MockKSCrashDependencies: SentryKSCrash.DependencyProvider {
    typealias Installing = MockKSCrashInstaller
    
    let kscrashInstaller: MockKSCrashInstaller

    init(installer: MockKSCrashInstaller = .init()) {
        self.kscrashInstaller = installer
    }
    
    func getKSCrashInstaller() -> MockKSCrashInstaller {
        return kscrashInstaller
    }
}

final class MockKSCrashInstaller: SentryKSCrash.Installing {
    public var installCalls: [(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool)] = []
    public var shouldThrow: Error?
    public var crashedLastLaunch: Bool = false
    public var installed: Bool = false

    public init() {}

    public func install(installPath: String, monitors: UInt, enableSwapCxaThrow: Bool) throws {
        installCalls.append((installPath: installPath, monitors: monitors, enableSwapCxaThrow: enableSwapCxaThrow))
        if let error = shouldThrow { throw error }
        installed = true
    }
}
#endif
