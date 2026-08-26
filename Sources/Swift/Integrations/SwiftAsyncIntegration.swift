internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
#if SDK_V10
        // KSCrash recording remains active after SDK close. Apply every SDK lifecycle's option,
        // including false, but preserve the configured value when this integration uninstalls.
        SentryKSCrash.CurrentThreadStackProvider.setSwiftAsyncStackTracesEnabled(
            options.swiftAsyncStacktraces
        )
        guard options.swiftAsyncStacktraces else { return nil }
#else
        guard options.swiftAsyncStacktraces else { return nil }
        sentrycrashsc_setSwiftAsyncStitching(true)
#endif
    }
    
    func uninstall() {
#if !SDK_V10
        sentrycrashsc_setSwiftAsyncStitching(false)
#endif
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
