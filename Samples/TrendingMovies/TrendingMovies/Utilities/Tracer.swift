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
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.environment = "integration-tests"
            options.debug = true

            if ProcessInfo().arguments.contains("--io.sentry.enable-profiling") {
                options.enableProfiling = true
            }
        }

        SentrySDK.configureScope { scope in
            scope.setTag(value: setUpInDidFinishLaunching ? "didFinishLaunching" : "willFinishLaunching", key: "launch-method")
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
        let span = SentrySDK.startTransaction(name: name, operation: "trending-movies-profiling-integration")
        tracer.currentSpan = span
        return SpanHandle(span: span)
    }

    struct SpanHandle {
        var span: Span

        func annotate(key: String, value: String) {
            print("[TrendingMovies] annotating span \(span.context.spanId.sentrySpanIdString), key \(key) and value \(value)")
            span.context.setTag(value: value, key: key)
        }

        func end() {
            print("[TrendingMovies] ending span \(span.context.spanId.sentrySpanIdString)")
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
