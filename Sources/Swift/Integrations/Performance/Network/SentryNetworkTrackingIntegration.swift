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

/// Routes process-lifetime swizzles to the tracker owned by the current SDK lifecycle.
/// A new tracker is registered when restarting the SDK with a new dependency container.
final class SentryNetworkTrackerProxy {
    // The proxy must not extend the tracker's integration and dependency-container lifetime.
    private final class WeakBox {
        weak var value: SentryNetworkTrackerProtocol?

        init(_ value: SentryNetworkTrackerProtocol) {
            self.value = value
        }
    }

    static let shared = SentryNetworkTrackerProxy()

    private let weakTarget = SentryMutex<WeakBox?>(nil)

    var target: SentryNetworkTrackerProtocol? {
        weakTarget.withLock { $0?.value }
    }

    func setTarget(_ target: SentryNetworkTrackerProtocol) {
        let reference = WeakBox(target)
        weakTarget.withLock { $0 = reference }
    }

    func removeTarget(_ target: SentryNetworkTrackerProtocol) {
        weakTarget.withLock {
            // An older integration must not remove a newer integration's tracker.
            guard $0?.value === target else {
                return
            }
            $0 = nil
        }
    }
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

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.sessionReplay.networkDetailHasUrls {
            Self.swizzleDataTaskWithRequestForResponseCapture()
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

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private static func swizzleDataTaskWithRequestForResponseCapture() {
        SentryTypedSwizzle.instanceMethod(
            in: URLSession.self,
            method: .urlSessionDataTaskWithRequest(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithRequest
        ) { _, request, completionHandler, original in
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
        }
    }

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
