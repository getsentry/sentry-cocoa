internal import _SentryPrivate
import Foundation

private enum SentryNetworkTrackingSwizzleKeys {
    static let resume = SentryTypedSwizzle.Key()
    static let state = SentryTypedSwizzle.Key()
    static let dataTaskWithRequest = SentryTypedSwizzle.Key()
    static let dataTaskWithURL = SentryTypedSwizzle.Key()
    static let dataTaskWithRequestForResponseCapture = SentryTypedSwizzle.Key()
    static let dataTaskWithURLForResponseCapture = SentryTypedSwizzle.Key()
    static let downloadTaskWithURL = SentryTypedSwizzle.Key()
    static let uploadTaskWithData = SentryTypedSwizzle.Key()
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
        SentryNetworkTrackerProxy.shared.setTarget(
            networkTracker,
            enableNewURLLoaderSwizzling: options.experimental.enableNewURLLoaderSwizzling
        )
        Self.swizzleURLSessionTasks()
        if options.experimental.enableNewURLLoaderSwizzling {
            Self.swizzleNewLoaderURLSessionTasks()
        }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
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
                keepTaskAliveDuringSwizzle(task)
                SentryNetworkTrackerProxy.shared.target?.urlSessionTaskResume(task)
                original()
            }

            SentryTypedSwizzle.instanceMethod(
                in: classToSwizzle,
                method: .urlSessionTaskState(URLSessionTask.self),
                mode: .oncePerClassAndSuperclasses,
                key: SentryNetworkTrackingSwizzleKeys.state
            ) { task, state, original in
                keepTaskAliveDuringSwizzle(task)
                SentryNetworkTrackerProxy.shared.target?.urlSessionTask(task, setState: state)
                original(state)
            }
        }
    }

    /// Extends the task's lifetime to the end of the current autorelease pool so it cannot be
    /// deallocated while the Objective-C method our swizzle runs inside is still executing.
    ///
    /// `-[NSURLSessionTask cancel]` calls `setState:` and then keeps messaging the task, for example
    /// `[self workQueue]`, without retaining it. A caller that holds the task through an unretained
    /// pointer, such as .NET's `NSUrlSessionHandler`, can drop its last reference from another thread
    /// while `cancel` is still running, freeing the task mid-cancel. Because our `resume` and
    /// `setState:` swizzles run synchronously inside those methods and widen that window, we take an
    /// autoreleased reference: the extra retain is established before the concurrent release and is
    /// balanced only when the pool drains, after the Objective-C method returns, so `cancel` never
    /// messages a freed task (see https://github.com/getsentry/sentry-cocoa/issues/8917).
    ///
    /// The retain must outlive the enclosing Objective-C method, so it relies on the caller's
    /// autorelease pool. Do not wrap the swizzle body in a local `@autoreleasepool`: that would
    /// balance the retain before `cancel` returns and reintroduce the crash.
    private static func keepTaskAliveDuringSwizzle(_ task: URLSessionTask) {
        _ = Unmanaged.passRetained(task).autorelease()
    }
}

private extension SentryNetworkTrackingIntegration {
    static func swizzleNewLoaderURLSessionTasks() {
#if compiler(>=6.1)
        guard #available(macOS 15.4, iOS 18.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *) else {
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.usesClassicLoadingMode = false
        let session = URLSession(configuration: configuration)
        guard let probeURL = URL(string: "https://example.com") else {
            return
        }
        let task = session.dataTask(with: probeURL)
        defer {
            task.cancel()
            session.finishTasksAndInvalidate()
        }

        let dataTaskSelector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        guard let sessionClass = classImplementing(dataTaskSelector, startingAt: type(of: session)),
              sessionClass !== URLSession.self,
              let taskClass = classImplementing(#selector(URLSessionTask.resume), startingAt: type(of: task)) else {
            return
        }

        SentryTypedSwizzle.instanceMethod(
            in: taskClass,
            method: .urlSessionTaskResume(URLSessionTask.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.resume
        ) { task, original in
            guard let tracker = SentryNetworkTrackerProxy.shared.newLoaderTarget else {
                return original()
            }
            keepTaskAliveDuringSwizzle(task)
            tracker.urlSessionTaskResume(task)
            original()
        }

        swizzleDataTaskWithRequest(in: sessionClass, completeTask: true)
        swizzleDataTaskWithURL(in: sessionClass, completeTask: true)
        swizzleDownloadTaskWithURL(in: sessionClass)
        swizzleUploadTaskWithData(in: sessionClass)
#endif
    }

    private static func classImplementing(_ selector: Selector, startingAt runtimeClass: AnyClass) -> AnyClass? {
        var currentClass: AnyClass? = runtimeClass
        while let candidate = currentClass {
            var methodCount: UInt32 = 0
            if let methods = class_copyMethodList(candidate, &methodCount) {
                defer { free(methods) }
                for index in 0..<Int(methodCount) where method_getName(methods[index]) == selector {
                    return candidate
                }
            }
            currentClass = class_getSuperclass(candidate)
        }
        return nil
    }

    private static func swizzleDownloadTaskWithURL(in sessionClass: AnyClass) {
        SentryTypedSwizzle.instanceMethod(
            in: sessionClass,
            method: .urlSessionDownloadTaskWithURL(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.downloadTaskWithURL
        ) { _, url, completionHandler, original in
            guard SentryNetworkTrackerProxy.shared.newLoaderTarget != nil else {
                return original(url, completionHandler)
            }
            var task: URLSessionDownloadTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { location, response, error in
                    if let task {
                        SentryNetworkTrackerProxy.shared.newLoaderTarget?.urlSessionTaskCompleted(
                            task,
                            error: error
                        )
                    }
                    completionHandler(location, response, error)
                } as SentryDownloadTaskCompletionHandler
            }
            let originalTask = original(url, wrappedHandler)
            originalTask.usesNewLoaderCompletionHandler = completionHandler != nil
            task = originalTask
            return originalTask
        }
    }

    private static func swizzleUploadTaskWithData(in sessionClass: AnyClass) {
        SentryTypedSwizzle.instanceMethod(
            in: sessionClass,
            method: .urlSessionUploadTaskWithData(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryNetworkTrackingSwizzleKeys.uploadTaskWithData
        ) { _, request, data, completionHandler, original in
            guard SentryNetworkTrackerProxy.shared.newLoaderTarget != nil else {
                return original(request, data, completionHandler)
            }
            var task: URLSessionUploadTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { responseData, response, error in
                    if let task {
                        SentryNetworkTrackerProxy.shared.newLoaderTarget?.urlSessionTaskCompleted(
                            task,
                            error: error
                        )
                    }
                    completionHandler(responseData, response, error)
                } as SentryDataTaskCompletionHandler
            }
            let originalTask = original(request, data, wrappedHandler)
            originalTask.usesNewLoaderCompletionHandler = completionHandler != nil
            task = originalTask
            return originalTask
        }
    }

    private static func swizzleDataTaskWithRequest(
        in sessionClass: AnyClass,
        completeTask: Bool
    ) {
        SentryTypedSwizzle.instanceMethod(
            in: sessionClass,
            method: .urlSessionDataTaskWithRequest(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: completeTask
                ? SentryNetworkTrackingSwizzleKeys.dataTaskWithRequest
                : SentryNetworkTrackingSwizzleKeys.dataTaskWithRequestForResponseCapture
        ) { _, request, completionHandler, original in
            if completeTask, SentryNetworkTrackerProxy.shared.newLoaderTarget == nil {
                return original(request, completionHandler)
            }
            var task: URLSessionDataTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { data, response, error in
                    let proxy = SentryNetworkTrackerProxy.shared
                    guard let tracker = completeTask ? proxy.newLoaderTarget : proxy.target else {
                        return completionHandler(data, response, error)
                    }
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
                    if error == nil, let data, let response, let requestURL = request.url, let task {
                        tracker.captureResponseDetails(
                            data,
                            response: response,
                            request: requestURL,
                            task: task
                        )
                    }
#endif
                    if completeTask, let task {
                        tracker.urlSessionTaskCompleted(
                            task,
                            error: error
                        )
                    }
                    completionHandler(data, response, error)
                } as SentryDataTaskCompletionHandler
            }
            let originalTask = original(request, wrappedHandler)
            if completeTask {
                originalTask.usesNewLoaderCompletionHandler = completionHandler != nil
            }
            task = originalTask
            return originalTask
        }
    }

    private static func swizzleDataTaskWithURL(
        in sessionClass: AnyClass,
        completeTask: Bool
    ) {
        SentryTypedSwizzle.instanceMethod(
            in: sessionClass,
            method: .urlSessionDataTaskWithURL(URLSession.self),
            mode: .oncePerClassAndSuperclasses,
            key: completeTask
                ? SentryNetworkTrackingSwizzleKeys.dataTaskWithURL
                : SentryNetworkTrackingSwizzleKeys.dataTaskWithURLForResponseCapture
        ) { _, url, completionHandler, original in
            if completeTask, SentryNetworkTrackerProxy.shared.newLoaderTarget == nil {
                return original(url, completionHandler)
            }
            var task: URLSessionDataTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { data, response, error in
                    let proxy = SentryNetworkTrackerProxy.shared
                    guard let tracker = completeTask ? proxy.newLoaderTarget : proxy.target else {
                        return completionHandler(data, response, error)
                    }
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
                    if error == nil, let data, let response, let task {
                        tracker.captureResponseDetails(
                            data,
                            response: response,
                            request: url,
                            task: task
                        )
                    }
#endif
                    if completeTask, let task {
                        tracker.urlSessionTaskCompleted(
                            task,
                            error: error
                        )
                    }
                    completionHandler(data, response, error)
                } as SentryDataTaskCompletionHandler
            }
            let originalTask = original(url, wrappedHandler)
            if completeTask {
                originalTask.usesNewLoaderCompletionHandler = completionHandler != nil
            }
            task = originalTask
            return originalTask
        }
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private static func swizzleDataTaskWithRequestForResponseCapture() {
        swizzleDataTaskWithRequest(in: URLSession.self, completeTask: false)
    }

    private static func swizzleDataTaskWithURLForResponseCapture() {
        swizzleDataTaskWithURL(in: URLSession.self, completeTask: false)
    }
#endif
}
