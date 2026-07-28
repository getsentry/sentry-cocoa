internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.swiftAsyncStacktraces else { return nil }

#if !ENABLE_KSCRASH
        // KSCRASH_TODO: sentrycrashsc_setSwiftAsyncStitching enables async stack stitching in
        // SentryCrash's stack cursor. KSCrash mode needs an equivalent opt-in to stitch
        // Swift async frames when building stack traces.
        sentrycrashsc_setSwiftAsyncStitching(true)
#endif // !ENABLE_KSCRASH
    }
    
    func uninstall() {
#if !ENABLE_KSCRASH
        sentrycrashsc_setSwiftAsyncStitching(false)
#endif // !ENABLE_KSCRASH
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
