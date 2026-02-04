@_implementationOnly import _SentryPrivate

final class SwiftAsyncIntegration<Dependencies>: SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.swiftAsyncStacktraces else { return nil }

        sentrycrashsc_setSwiftAsyncStitching(true)
    }
    
    func uninstall() {
        sentrycrashsc_setSwiftAsyncStitching(false)
    }
    
    static var name: String {
        "SentrySwiftAsyncIntegration"
    }
}
