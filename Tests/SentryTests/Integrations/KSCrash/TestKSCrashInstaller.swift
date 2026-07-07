#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import KSCrashRecording

/// Test double for `SentryKSCrashInstalling` that records the configuration it was
/// asked to install instead of touching the global `KSCrash.shared` singleton.
final class TestKSCrashInstaller: SentryKSCrashInstalling {
    private(set) var installCallCount = 0
    private(set) var installedConfiguration: KSCrashConfiguration?
    var errorToThrow: Error?

    func install(with configuration: KSCrashConfiguration) throws {
        installCallCount += 1
        installedConfiguration = configuration
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

/// Supplies a `TestKSCrashInstaller` to `SentryKSCrashIntegration`.
struct MockKSCrashDependencies: KSCrashIntegrationProvider {
    let ksCrashInstaller: SentryKSCrashInstalling
}
#endif
