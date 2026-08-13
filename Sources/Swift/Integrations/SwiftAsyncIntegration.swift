internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.swiftAsyncStacktraces else { return nil }

#if SENTRY_DISABLE_SENTRYCRASH_V10
        // KSCRASH_TODO(GH-8725): V10 warns and leaves Swift async stitching disabled.
        // Acceptance: SCV10-011 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        SentrySDKLog.warning("Swift async stack traces are not yet connected to KSCrash.")
        return nil
#else
        sentrycrashsc_setSwiftAsyncStitching(true)
#endif
    }
    
    func uninstall() {
#if !SENTRY_DISABLE_SENTRYCRASH_V10
        sentrycrashsc_setSwiftAsyncStitching(false)
#else
        // KSCRASH_TODO(GH-8725): V10 did not enable Swift async stitching, so uninstall is a no-op.
        // Acceptance: SCV10-011 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
#endif
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
