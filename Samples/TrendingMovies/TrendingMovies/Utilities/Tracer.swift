import Foundation
import OSLog
import Sentry

/// A struct that manages performance tracing in the app.
struct Tracer {
    private static let log = OSLog(subsystem: "io.sentry.sample.TrendingMovies", category: "TrendingMovies")
    private static var tracer = Tracer()

    @available(iOS 12.0, macOS 10.14, tvOS 12.0, watchOS 5.0, *)
    private static let ident = OSSignpostID(log: log)

    private static let didFinishDebugMenuOptionSet = false // TODO: implement check for this debug menu option, if/when we bring in the debug menu

    private var currentSpan: Span?
}

// MARK: Configuration

extension Tracer {
    /// - Parameter finishedLaunching: `false` if this function is called from `-[UIApplicationDelegate willFinishLaunchingWithOptions:]`, `true` if it's called from `-[UIApplicationDelegate didFinishLaunchingWithOptions`
    static func setUp(finishedLaunching: Bool) {
        let didFinishLaunchArgSet = ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.setup-in-didfinishlaunching")
        let setUpInDidFinishLaunching = didFinishLaunchArgSet || didFinishDebugMenuOptionSet

        guard (finishedLaunching && setUpInDidFinishLaunching) || (!finishedLaunching && !setUpInDidFinishLaunching) else {
            return
        }

        SentrySDK.start { options in
            options.dsn = "https://fff20ae0c1d141fda99ba8bdedd0e9cd@o447951.ingest.sentry.io/6509889"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
            options.enableFileIOTracing = true
            options.enableCoreDataTracing = true
            options.profilesSampleRate = 1.0
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.enableUserInteractionTracing = true
        }

        SentrySDK.configureScope { scope in
            scope.setTag(value: setUpInDidFinishLaunching ? "didFinishLaunching" : "willFinishLaunching", key: "launch-method")
            scope.setTag(value: "\(ProcessInfo.processInfo.arguments.contains("--io.sentry.sample.trending-movies.launch-arg.efficient-implementation"))", key: "efficient-implementation")
        }
    }
}

// MARK: Tracing

extension Tracer {
    static func startTracing(interaction: String) {
        print("[TrendingMovies] starting trace with interaction name \(interaction)")
        tracer.currentSpan = SentrySDK.startTransaction(name: interaction, operation: "sentry-movies-transaction")
    }

    static func endTracing(interaction: String) {
        print("[TrendingMovies] ending trace with interaction name \(interaction)")
        tracer.currentSpan?.finish()
    }
}

// MARK: Spans

extension Tracer {
    static func startSpan(name: String) -> SpanHandle {
        print("[TrendingMovies] starting span \(name)")
        let span = SentrySDK.startTransaction(name: name, operation: "trending-movies-profiling-integration")
        return SpanHandle(span: span)
    }

    struct SpanHandle {
        var span: Span

        func annotate(key: String, value: String) {
            print("[TrendingMovies] annotating span \(span.spanId.sentrySpanIdString), key \(key) and value \(value)")
            span.setTag(value: value, key: key)
        }

        func end() {
            print("[TrendingMovies] ending span \(span.spanId.sentrySpanIdString)")
            span.finish()
        }
    }
}

// MARK: Networking

extension Tracer {
    /// A class to test our NSURLSession instrumentation when proxying to a customer's delegate that also implements the same protocol functions we need to gather the desired metrics.
    private class NSURLSessionDelegateWithProxiedCallbacks: NSObject, URLSessionTaskDelegate {
        func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            print("[TrendingMovies] - [NSURLSessionTaskDelegate URLSession:task:didFinishCollectingMetrics:] called in consumer app's own delegate callback with metrics: \(metrics).")
        }
    }

    /// A class to test our NSURLSession instrumentation when proxying to a customer's delegate that does not implement the same protocol functions we need to gather the desired metrics.
    private class NSURLSessionDelegateWithoutProxiedCallbacks: NSObject, URLSessionTaskDelegate {}
}
