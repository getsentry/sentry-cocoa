internal import _SentryPrivate
import Foundation

private enum SentryNetworkTrackingSwizzleKeys {
    static let resume = SentryTypedSwizzle.Key()
    static let state = SentryTypedSwizzle.Key()

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    static let dataTaskWithRequest = SentryTypedSwizzle.Key()
    static let dataTaskWithURL = SentryTypedSwizzle.Key()
#endif
}

final class SentryNetworkTrackingIntegration<Dependencies: NetworkTrackerProvider>: NSObject, SwiftIntegration {

    /// References the shared `SentryNetworkTracker` instance (injected via dependencies).
    ///
    /// URLSession swizzling can only be applied once per process, so the same tracker instance
    /// must persist across SDK restarts. Once swizzling supports re-application, this can be
    /// replaced with a new instance per integration lifecycle.
    private let networkTracker: SentryNetworkTracker

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        let shouldEnableNetworkTracking = Self.shouldBeEnabled(with: options)
        networkTracker = dependencies.networkTracker

        if shouldEnableNetworkTracking {
            networkTracker.enableNetworkTracking()
        }

        if options.enableNetworkBreadcrumbs {
            networkTracker.enableNetworkBreadcrumbs()
        }

        if options.enableCaptureFailedRequests {
            networkTracker.enableCaptureFailedRequests()
        }

        if options.enableGraphQLOperationTracking {
            networkTracker.enableGraphQLOperationTracking()
        }

        guard shouldEnableNetworkTracking || options.enableNetworkBreadcrumbs || options.enableCaptureFailedRequests else {
            return nil
        }

        super.init()

        swizzleURLSessionTasks()

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.sessionReplay.networkDetailHasUrls {
            swizzleDataTaskWithRequestForResponseCapture()
            swizzleDataTaskWithURLForResponseCapture()
        }
#endif
    }

    func uninstall() {
        networkTracker.disable()
    }

    static var name: String {
        "SentryNetworkTrackingIntegration"
    }

    private static func shouldBeEnabled(with options: Options) -> Bool {
        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(name) because isTracingEnabled is disabled.")
            return false
        }

        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(name) because enableAutoPerformanceTracing is disabled.")
            return false
        }

        guard options.enableNetworkTracking else {
            SentrySDKLog.debug("Not going to enable \(name) because enableNetworkTracking is disabled.")
            return false
        }

        return true
    }

    // MARK: - Swizzling

    private func swizzleURLSessionTasks() {
        for classToSwizzle in SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack() {
            SentryTypedSwizzle.instanceMethod(
                in: classToSwizzle,
                method: .urlSessionTaskResume(URLSessionTask.self),
                mode: .oncePerClassAndSuperclasses,
                key: SentryNetworkTrackingSwizzleKeys.resume
            ) { [networkTracker] task, original in
                networkTracker.urlSessionTaskResume(task)
                original()
            }

            SentryTypedSwizzle.instanceMethod(
                in: classToSwizzle,
                method: .urlSessionTaskState(URLSessionTask.self),
                mode: .oncePerClassAndSuperclasses,
                key: SentryNetworkTrackingSwizzleKeys.state
            ) { [networkTracker] task, state, original in
                networkTracker.urlSessionTask(task, setState: state)
                original(state)
            }
        }
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private func swizzleDataTaskWithRequestForResponseCapture() {
        SentryTypedSwizzle.instanceMethod(
            in: URLSession.self,
            method: .urlSessionDataTaskWithRequest(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithRequest
        ) { [networkTracker] _, request, completionHandler, original in
            var task: URLSessionDataTask?
            var wrappedHandler: SentryDataTaskCompletionHandler?
            if let completionHandler {
                wrappedHandler = { data, response, error in
                    if error == nil, let data, let response, let task {
                        networkTracker.captureResponseDetails(
                            data,
                            response: response,
                            request: request.url,
                            task: task
                        )
                    }
                    completionHandler(data, response, error)
                }
            }
            let originalTask = original(request, wrappedHandler)
            task = originalTask
            return originalTask
        }
    }

    private func swizzleDataTaskWithURLForResponseCapture() {
        SentryTypedSwizzle.instanceMethod(
            in: URLSession.self,
            method: .urlSessionDataTaskWithURL(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithURL
        ) { [networkTracker] _, url, completionHandler, original in
            var task: URLSessionDataTask?
            var wrappedHandler: SentryDataTaskCompletionHandler?
            if let completionHandler {
                wrappedHandler = { data, response, error in
                    if error == nil, let data, let response, let task {
                        networkTracker.captureResponseDetails(
                            data,
                            response: response,
                            request: url,
                            task: task
                        )
                    }
                    completionHandler(data, response, error)
                }
            }
            let originalTask = original(url, wrappedHandler)
            task = originalTask
            return originalTask
        }
    }
#endif
}
