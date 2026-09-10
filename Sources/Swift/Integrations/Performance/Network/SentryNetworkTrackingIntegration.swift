internal import _SentryPrivate
import Foundation

private enum SentryNetworkTrackingSwizzleKeys {
    static let resume = SentryTypedSwizzle.Key()
    static let state = SentryTypedSwizzle.Key()
    static let dataTaskWithRequest = SentryTypedSwizzle.Key()

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    static let dataTaskWithURL = SentryTypedSwizzle.Key()
#endif
}

final class SentryNetworkTrackingIntegration<Dependencies: NetworkTrackerProvider>: NSObject, SwiftIntegration {

    private let networkTracker: SentryNetworkTrackerProtocol

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

        // Swizzling is idempotent because each method uses a stable key with
        // oncePerClassAndSuperclasses. On SDK restart, existing swizzles remain installed and the
        // proxy routes them to this new tracker instead.
        SentryNetworkTrackerProxy.shared.setTarget(networkTracker)
        Self.swizzleURLSessionTasks()

        // Inject trace-propagation headers at task-creation time so we don't mutate the live task's
        // currentRequest on resume. Applies to request-based data tasks on all platforms.
        Self.swizzleDataTaskWithRequest()

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.sessionReplay.networkDetailHasUrls {
            Self.swizzleDataTaskWithURLForResponseCapture()
        }
#endif
    }

    func uninstall() {
        networkTracker.disable()
        SentryNetworkTrackerProxy.shared.removeTarget(networkTracker)
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

    private static func swizzleURLSessionTasks() {
        for classToSwizzle in SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack() {
            SentryTypedSwizzle.instanceMethod(
                in: classToSwizzle,
                method: .urlSessionTaskResume(URLSessionTask.self),
                mode: .oncePerClassAndSuperclasses,
                key: SentryNetworkTrackingSwizzleKeys.resume
            ) { task, original in
                SentryNetworkTrackerProxy.shared.target?.urlSessionTaskResume(task)
                original()
            }

            SentryTypedSwizzle.instanceMethod(
                in: classToSwizzle,
                method: .urlSessionTaskState(URLSessionTask.self),
                mode: .oncePerClassAndSuperclasses,
                key: SentryNetworkTrackingSwizzleKeys.state
            ) { task, state, original in
                SentryNetworkTrackerProxy.shared.target?.urlSessionTask(task, setState: state)
                original(state)
            }
        }
    }

    private static func swizzleDataTaskWithRequest() {
        SentryTypedSwizzle.instanceMethod(
            in: URLSession.self,
            method: .urlSessionDataTaskWithRequest(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithRequest
        ) { _, request, completionHandler, original in
            // Inject trace-propagation headers before the task is created. Falls back to the
            // unchanged request when there is no target, so this is safe for every request.
            let request = SentryNetworkTrackerProxy.shared.target?.injectTraceHeaders(intoRequest: request) ?? request

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            var task: URLSessionDataTask?
            var wrappedHandler: SentryDataTaskCompletionHandler?
            if let completionHandler {
                wrappedHandler = { data, response, error in
                    if error == nil, let data, let response, let requestURL = request.url, let task {
                        SentryNetworkTrackerProxy.shared.target?.captureResponseDetails(
                            data,
                            response: response,
                            request: requestURL,
                            task: task
                        )
                    }
                    completionHandler(data, response, error)
                }
            }
            let originalTask = original(request, wrappedHandler)
            task = originalTask
            return originalTask
#else
            return original(request, completionHandler)
#endif
        }
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private static func swizzleDataTaskWithURLForResponseCapture() {
        SentryTypedSwizzle.instanceMethod(
            in: URLSession.self,
            method: .urlSessionDataTaskWithURL(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithURL
        ) { _, url, completionHandler, original in
            var task: URLSessionDataTask?
            var wrappedHandler: SentryDataTaskCompletionHandler?
            if let completionHandler {
                wrappedHandler = { data, response, error in
                    if error == nil, let data, let response, let task {
                        SentryNetworkTrackerProxy.shared.target?.captureResponseDetails(
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
