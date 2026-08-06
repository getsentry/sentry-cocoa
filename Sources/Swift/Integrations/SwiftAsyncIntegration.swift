internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.swiftAsyncStacktraces else { return nil }

#if SENTRY_DISABLE_SENTRYCRASH_V10
        SentrySDKLog.warning("Swift async stack traces are not yet connected to KSCrash.")
        return nil
#else
        sentrycrashsc_setSwiftAsyncStitching(true)
#endif
    }
    
    func uninstall() {
#if !SENTRY_DISABLE_SENTRYCRASH_V10
        sentrycrashsc_setSwiftAsyncStitching(false)
#endif
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
