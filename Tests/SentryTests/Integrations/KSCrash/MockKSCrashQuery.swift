#if SDK_V10
@_spi(Private) @testable import Sentry

enum MockKSCrashQuery {
    static func create(
        installed: Bool = false,
        crashedLastLaunch: Bool = false
    ) -> SentryKSCrash.Query {
        let mockInstaller = MockKSCrashInstaller()
        mockInstaller.installed = installed
        mockInstaller.crashedLastLaunch = crashedLastLaunch

        return SentryKSCrash.Query(installer: mockInstaller)
    }
}
#endif
