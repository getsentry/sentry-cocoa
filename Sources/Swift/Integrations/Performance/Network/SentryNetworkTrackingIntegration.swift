internal import _SentryPrivate
import Foundation

private enum SentryNetworkTrackingSwizzleKeys {
    static let resume = SentryTypedSwizzle.Key()
    static let state = SentryTypedSwizzle.Key()
    static let dataTaskWithRequest = SentryTypedSwizzle.Key()
    static let dataTaskWithURL = SentryTypedSwizzle.Key()
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
        SentryNetworkTrackerProxy.shared.setTarget(networkTracker)
        Self.swizzleURLSessionTasks()
        Self.swizzleNewLoaderURLSessionTasks()

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
            SentryNetworkTrackerProxy.shared.target?.urlSessionTaskResume(task)
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
            var task: URLSessionDownloadTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { location, response, error in
                    if let task {
                        SentryNetworkTrackerProxy.shared.target?.urlSessionTaskCompleted(
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
            var task: URLSessionUploadTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { responseData, response, error in
                    if let task {
                        SentryNetworkTrackerProxy.shared.target?.urlSessionTaskCompleted(
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
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithRequest
        ) { _, request, completionHandler, original in
            var task: URLSessionDataTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { data, response, error in
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
                    if error == nil, let data, let response, let requestURL = request.url, let task {
                        SentryNetworkTrackerProxy.shared.target?.captureResponseDetails(
                            data,
                            response: response,
                            request: requestURL,
                            task: task
                        )
                    }
#endif
                    if completeTask, let task {
                        SentryNetworkTrackerProxy.shared.target?.urlSessionTaskCompleted(
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
            key: SentryNetworkTrackingSwizzleKeys.dataTaskWithURL
        ) { _, url, completionHandler, original in
            var task: URLSessionDataTask?
            let wrappedHandler = completionHandler.map { completionHandler in
                { data, response, error in
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
                    if error == nil, let data, let response, let task {
                        SentryNetworkTrackerProxy.shared.target?.captureResponseDetails(
                            data,
                            response: response,
                            request: url,
                            task: task
                        )
                    }
#endif
                    if completeTask, let task {
                        SentryNetworkTrackerProxy.shared.target?.urlSessionTaskCompleted(
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

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private static func swizzleDataTaskWithRequestForResponseCapture() {
        swizzleDataTaskWithRequest(in: URLSession.self, completeTask: false)
    }

    private static func swizzleDataTaskWithURLForResponseCapture() {
        swizzleDataTaskWithURL(in: URLSession.self, completeTask: false)
    }
#endif
}
