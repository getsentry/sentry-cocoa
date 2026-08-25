internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.swiftAsyncStacktraces else { return nil }
#if SDK_V10
        SentryKSCrash.CurrentThreadStackProvider.setSwiftAsyncStackTracesEnabled(true)
#else
        sentrycrashsc_setSwiftAsyncStitching(true)
#endif
    }
    
    func uninstall() {
#if SDK_V10
        SentryKSCrash.CurrentThreadStackProvider.setSwiftAsyncStackTracesEnabled(false)
#else
        sentrycrashsc_setSwiftAsyncStitching(false)
#endif
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
