#if SENTRY_DISABLE_SENTRYCRASH_V10
internal import _SentryPrivate
import Foundation

extension SentryKSCrash {
    /// Keeps reporter-neutral consumers buildable without emulating capabilities that have not
    /// been migrated from SentryCrash. Installation state comes from `SentryKSCrash.Query`.
    final class UnavailableReporter: NSObject, SentryCrashReporter {
        let processInfoWrapper: SentryProcessInfoSource
        let systemInfo: [String: Any] = [:]
        var introspectMemory = false

        init(processInfoWrapper: SentryProcessInfoSource) {
            self.processInfoWrapper = processInfoWrapper
            super.init()
        }

        var installed: Bool { false }
        var crashedLastLaunch: Bool { false }
        var durationFromCrashStateInitToLastCrash: TimeInterval { 0 }
        var activeDurationSinceLastCrash: TimeInterval { 0 }
        var freeMemorySize: UInt64 { 0 }
        var appMemorySize: UInt64 { 0 }

        var isSimulatorBuild: Bool {
#if targetEnvironment(simulator)
            true
#else
            false
#endif
        }

        func startBinaryImageCache() { }
        func stopBinaryImageCache() { }
        func enrichScope(_ scope: Scope) { }
    }
}
#endif // SENTRY_DISABLE_SENTRYCRASH_V10
