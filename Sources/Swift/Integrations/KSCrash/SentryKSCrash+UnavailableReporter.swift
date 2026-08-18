#if SDK_V10
internal import _SentryPrivate
import Foundation

typealias SentryScope = Scope

extension SentryKSCrash {
    /// Keeps reporter-neutral consumers buildable without emulating capabilities that have not
    /// been migrated from SentryCrash. Installation state comes from `SentryKSCrash.Query`.
    final class UnavailableReporter: NSObject, SentryCrashReporter {
        let processInfoWrapper: SentryProcessInfoSource
#if SENTRY_DISABLE_SENTRYCRASH_V10
        // KSCRASH_TODO(GH-8800): Replace the empty system context with the reporter-neutral
        // enricher. Acceptance: SCV10-017 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        let systemInfo: [String: Any] = [:]
#endif
        var introspectMemory = false

        init(processInfoWrapper: SentryProcessInfoSource) {
            self.processInfoWrapper = processInfoWrapper
            super.init()
        }

        var installed: Bool { false }
        var crashedLastLaunch: Bool { false }
        var durationFromCrashStateInitToLastCrash: TimeInterval { 0 }
        var activeDurationSinceLastCrash: TimeInterval { 0 }
#if SENTRY_DISABLE_SENTRYCRASH_V10
        // KSCRASH_TODO(GH-8800): Zero is a temporary V10 fallback, not a valid memory metric.
        // Acceptance: SCV10-016 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        var freeMemorySize: UInt64 { 0 }
        var appMemorySize: UInt64 { 0 }
#endif

        var isSimulatorBuild: Bool {
#if targetEnvironment(simulator)
            true
#else
            false
#endif
        }

#if SENTRY_DISABLE_SENTRYCRASH_V10
        // KSCRASH_TODO(GH-8800): Initial OS/device/app/runtime scope enrichment is omitted.
        // Acceptance: SCV10-017 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        func enrichScope(_ scope: SentryScope) { }
#endif
    }
}
#endif // SDK_V10
