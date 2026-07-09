//#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry

/// Test double for `SentryKSCrashInstalling` that records the configuration it was
/// asked to install instead of touching the global `KSCrash.shared` singleton.
///
/// It records the Sentry-owned `SentryKSCrashConfiguration`, so the test target never
/// imports `KSCrashRecording` (keeping the KSCrash package out of the test build).
final class TestKSCrashInstaller: SentryKSCrashInstalling {
    private(set) var installCallCount = 0
    private(set) var installedConfiguration: SentryKSCrashConfiguration?
    var errorToThrow: Error?

    func install(with configuration: SentryKSCrashConfiguration) throws {
        installCallCount += 1
        installedConfiguration = configuration
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

/// Supplies a `TestKSCrashInstaller` to `SentryKSCrashIntegration`.
struct MockKSCrashDependencies: KSCrashInstallerProvider {
    let ksCrashInstaller: any SentryKSCrashInstalling
//    let ksCrashInstaller: SentryKSCrashInstalling
}
//#endif
