#if SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif

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
