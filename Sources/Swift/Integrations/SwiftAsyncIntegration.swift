internal import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        // KSCrash recording remains active after SDK close. Apply every SDK lifecycle's option,
        // including false, but preserve the configured value when this integration uninstalls.
        SentryKSCrash.CurrentThreadStackProvider.setSwiftAsyncStackTracesEnabled(
            options.swiftAsyncStacktraces
        )
        guard options.swiftAsyncStacktraces else { return nil }
    }
    
    func uninstall() {
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
