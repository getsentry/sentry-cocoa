// swiftlint:disable type_body_length file_length
internal import _SentryPrivate

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryNetworkTrackerProtocol {
    func enableNetworkTracking()
    func enableNetworkBreadcrumbs()
    func enableCaptureFailedRequests()
    func enableGraphQLOperationTracking()
    func disable()

    var isNetworkTrackingEnabled: Bool { get }
    var isNetworkBreadcrumbEnabled: Bool { get }
    var isCaptureFailedRequestsEnabled: Bool { get }
    var isGraphQLOperationTrackingEnabled: Bool { get }

    func urlSessionTaskResume(_ sessionTask: URLSessionTask)
    func urlSessionTask(_ sessionTask: URLSessionTask, setState newState: URLSessionTask.State)
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    func captureResponseDetails(_ data: Data, response: URLResponse, request requestURL: URL, task: URLSessionTask)
#endif
}

extension SentryDefaultNetworkTracker: SentryNetworkTrackerProtocol {}

typealias SentryDefaultNetworkTrackerDependencies = CurrentDateProvider & HubProvider & ThreadInspectorProvider
#else
typealias SentryNetworkTrackerProtocol = SentryDefaultNetworkTracker<SentryDependencyContainer>
typealias SentryDefaultNetworkTrackerDependencies = SentryDependencyContainer
#endif

final class SentryDefaultNetworkTracker<Dependencies: SentryDefaultNetworkTrackerDependencies> {
    // MARK: - State

    private let dateProvider: SentryCurrentDateProvider
    private let hub: Hub
    private let threadInspector: SentryThreadInspector

    private(set) var isNetworkTrackingEnabled = false
    private(set) var isNetworkBreadcrumbEnabled = false
    private(set) var isCaptureFailedRequestsEnabled = false
    private(set) var isGraphQLOperationTrackingEnabled = false

    // MARK: - Initializers

    init(options: Options?, dependencies: Dependencies) {
        self.dateProvider = dependencies.dateProvider
        self.hub = dependencies.hub
        self.threadInspector = dependencies.threadInspector
    }

    // MARK: - Public API

    func enableNetworkTracking() {
        isNetworkTrackingEnabled = true
    }

    func enableNetworkBreadcrumbs() {
        isNetworkBreadcrumbEnabled = true
    }

    func enableCaptureFailedRequests() {
        isCaptureFailedRequestsEnabled = true
    }

    func enableGraphQLOperationTracking() {
        isGraphQLOperationTrackingEnabled = true
    }

    func disable() {
        isNetworkTrackingEnabled = false
        isNetworkBreadcrumbEnabled = false
        isCaptureFailedRequestsEnabled = false
        isGraphQLOperationTrackingEnabled = false
    }

    // MARK: - URL Session Handling

    // swiftlint:disable cyclomatic_complexity function_body_length
    func urlSessionTaskResume(_ sessionTask: URLSessionTask) {
        let sessionState = sessionTask.state
        if sessionState == .completed || sessionState == .canceling {
            return
        }

        guard isTaskSupported(sessionTask) else {
            return
        }

        // No options set means the SDK is not enabled
        guard let options = hub.currentOptions else {
            return
        }

        // Snapshot currentRequest once — the property is volatile and can return a freed
        // object if the task completes on another thread between repeated accesses.
        guard let currentRequest = sessionTask.currentRequest,
              let url = currentRequest.url else {
            return
        }

        // Don't measure requests to Sentry's backend
        if isSentryRequest(url, options: options) {
            return
        }

        if isNetworkBreadcrumbEnabled {
            switch sessionTask.startDate {
            case .valid:
                break
            case .invalid(let value):
                SentrySDKLog.error("Found invalid type associated with session start date: \(value)")
                sessionTask.setStartDate(dateProvider.date())
            case nil:
                sessionTask.setStartDate(dateProvider.date())
            }
        }

        guard isNetworkTrackingEnabled else {
            addTraceWithoutTransaction(to: sessionTask)
            return
        }

        #if SDK_V10
        let safeUrl = UrlSanitized(URL: url, options: options.dataCollection)
        #else
        let safeUrl = UrlSanitized(URL: url)
        #endif

        synchronized(sessionTask) {
            guard sessionTask.trackerSpan == nil else {
                // The task already has a span. Nothing to do.
                return
            }

            let currentSpan = hub.scope.span
            var networkSpan: Span?

            if let currentSpan {
                #if SDK_V10
                let descriptionUrl = safeUrl.sanitizedBaseUrl
                #else
                let descriptionUrl = safeUrl.sanitizedUrl
                #endif

                networkSpan = currentSpan.startChild(
                    operation: SentrySpanOperationNetworkRequestOperation,
                    description: String(
                        format: "%@ %@",
                        currentRequest.httpMethod ?? "<null>",
                        descriptionUrl ?? "<null>"
                    )
                )
                networkSpan?.origin = SentryTraceOriginAutoHttpNSURLSession
                networkSpan?.setData(value: currentRequest.httpMethod, key: "http.request.method")
                networkSpan?.setData(value: safeUrl.sanitizedUrl, key: "url")
                networkSpan?.setData(value: "fetch", key: "type")

                if let queryItems = safeUrl.queryItems, !queryItems.isEmpty {
                    networkSpan?.setData(value: safeUrl.query, key: "http.query")
                }
                if let fragment = safeUrl.fragment {
                    networkSpan?.setData(value: fragment, key: "http.fragment")
                }
            }

            // We only create a span if there is a transaction in the scope,
            // otherwise we have nothing else to do here.
            guard let networkSpan, !(networkSpan is SentryNoOpSpan) else {
                SentrySDKLog.debug("No transaction bound to scope. Won't track network operation.")
                addTraceWithoutTransaction(to: sessionTask)
                return
            }

            if let baggage = SentryTracer.getTracer(currentSpan)?.traceContext?.toBaggage() {
                SentryTracePropagation.addBaggageHeader(
                    baggage,
                    traceHeader: networkSpan.toTraceHeader(),
                    propagateTraceparent: hub.options.enablePropagateTraceparent,
                    tracePropagationTargets: hub.options.tracePropagationTargets,
                    toRequest: sessionTask
                )
            }

            SentrySDKLog.debug("SentryNetworkTracker automatically started HTTP span for sessionTask: \(networkSpan.description)")
            sessionTask.setTrackerSpan(networkSpan)
        }
    }

    func urlSessionTask(_ sessionTask: URLSessionTask, setState newState: URLSessionTask.State) {
        if !isNetworkTrackingEnabled && !isNetworkBreadcrumbEnabled && !isCaptureFailedRequestsEnabled {
            return
        }

        guard isTaskSupported(sessionTask), let options = hub.currentOptions else {
            return
        }

        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        if let urlString = sessionTask.originalRequest?.url?.absoluteString,
           isNetworkDetailCaptureEnabled(for: urlString, options: options) {
            captureRequestDetails(
                for: sessionTask,
                networkCaptureBodies: options.sessionReplay.networkCaptureBodies,
                networkRequestHeaders: options.sessionReplay.networkRequestHeaders
            )
        }
        #endif

        // Suspended is not terminal because the task may be resumed or cancelled later.
        if newState == .running || newState == .suspended {
            return
        }

        guard let currentRequest = sessionTask.currentRequest, let url = currentRequest.url else {
            return
        }

        if isSentryRequest(url, options: options) {
            return
        }

        // We'll just go through once
        let networkSpan: Span? = synchronized(sessionTask) {
            defer { sessionTask.setTrackerSpan(nil) }

            switch sessionTask.trackerSpan {
            case .valid(let span):
                return span
            case .invalid(let value):
                SentrySDKLog.error("Found invalid tracker span associated with URL session task: \(value)")
                return nil
            case nil:
                return nil
            }
        }

        // Capture breadcrumbs, failed requests, and response status codes on the first terminal
        // transition. Because our swizzle runs before the original setState:, sessionTask.state
        // still reflects the previous state. We check for Running and Suspended to cover:
        //   - running → completed/canceling (normal completion or cancellation)
        //   - suspended → canceling (task cancelled while suspended)
        if sessionTask.state == .running || sessionTask.state == .suspended {
            captureFailedRequest(for: sessionTask, currentRequest: currentRequest, options: options)
            addBreadcrumb(for: sessionTask, currentRequest: currentRequest, options: options)

            let responseStatusCode = urlResponseStatusCode(sessionTask.response)
            if responseStatusCode != -1 {
                networkSpan?.setData(value: responseStatusCode, key: "http.response.status_code")
            }
        }

        guard let networkSpan else {
            return
        }

        networkSpan.finish(status: status(for: sessionTask, state: newState))
        SentrySDKLog.debug("SentryNetworkTracker finished HTTP span for sessionTask")
    }

    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    func captureResponseDetails(_ data: Data, response: URLResponse, request requestURL: URL, task: URLSessionTask) {
        let urlString = requestURL.absoluteString
        guard let options = hub.currentOptions,
              isNetworkDetailCaptureEnabled(for: urlString, options: options) else {
            return
        }

        synchronized(task) {
            guard case .valid(let details) = task.networkDetails else {
                SentrySDKLog.warning("[NetworkCapture] No SentryReplayNetworkDetails found for \(urlString) - skipping response capture")
                return
            }

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            // swiftlint:disable avoid_all_header_fields
            // Safe: reading the whole dictionary, not a case-sensitive lookup.
            let allHeaders = httpResponse?.allHeaderFields.reduce(into: [String: Any]()) { result, entry in
                guard let key = entry.key as? String else {
                    return
                }
                result[key] = entry.value
            }
            // swiftlint:enable avoid_all_header_fields
            let contentType = httpResponse?.value(forHTTPHeaderFieldCaseInsensitive: "content-type")
            let bodyData = options.sessionReplay.networkCaptureBodies && !data.isEmpty ? data : nil

            details.setResponse(
                statusCode: statusCode,
                size: NSNumber(value: data.count),
                bodyData: bodyData,
                contentType: contentType,
                allHeaders: allHeaders,
                configuredHeaders: options.sessionReplay.networkResponseHeaders
            )
        }
    }
    #endif

    // MARK: - Failed requests

    private func captureFailedRequest(for sessionTask: URLSessionTask, currentRequest: URLRequest, options: Options) {
        guard isCaptureFailedRequestsEnabled else {
            SentrySDKLog.debug("captureFailedRequestsEnabled is disabled, not capturing HTTP Client errors.")
            return
        }

        guard let response = sessionTask.response else {
            SentrySDKLog.debug("Request or Response are null, not capturing HTTP Client errors.")
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            SentrySDKLog.debug("Response isn't a known type, not capturing HTTP Client errors.")
            return
        }

        guard containsStatusCode(httpResponse.statusCode, options: options) else {
            SentrySDKLog.debug("Response status code isn't within the allowed ranges, not capturing HTTP Client errors.")
            return
        }

        guard let requestURL = currentRequest.url,
              SentryTracePropagation.isTargetMatch(requestURL, withTargets: options.failedRequestTargets) else {
            SentrySDKLog.debug("Request url isn't within the request targets, not capturing HTTP Client errors.")
            return
        }

        let message = "HTTP Client Error with status code: \(httpResponse.statusCode)"
        let event = Event(level: .error)
        let exception = Exception(value: message, type: "HTTPClientError")
        exception.mechanism = Mechanism(type: "HTTPClientError")

        if let thread = threadInspector.getCurrentThreads().first(where: { $0.current?.boolValue == true }) {
            thread.stacktrace?.snapshot = true
            exception.stacktrace = thread.stacktrace
        }

        let request = SentryRequest()
        #if SDK_V10
        let sanitizedURL = UrlSanitized(URL: requestURL, options: options.dataCollection)
        #else
        let sanitizedURL = UrlSanitized(URL: requestURL)
        #endif

        request.url = sanitizedURL.sanitizedUrl
        request.method = currentRequest.httpMethod
        request.fragment = sanitizedURL.fragment
        request.queryString = sanitizedURL.query
        request.bodySize = NSNumber(value: sessionTask.countOfBytesSent)
        if let headers = currentRequest.allHTTPHeaderFields {
            #if SDK_V10
            let sanitizedHeaders = HTTPHeaderSanitizer.sanitizeRequestHeaders(
                headers,
                options: options.dataCollection
            )
            request.headers = sanitizedHeaders.headers
            request.cookies = sanitizedHeaders.cookies
            #else
            request.headers = HTTPHeaderSanitizer.sanitizeHeaders(headers)
            #endif
        }

        event.exceptions = [exception]
        event.request = request

        var responseContext: [String: Any] = ["status_code": httpResponse.statusCode]
        // Safe: reading the whole dictionary, not a case-sensitive single-header lookup.
        // swiftlint:disable avoid_all_header_fields
        let responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String, let value = entry.value as? String else {
                return
            }
            result[key] = value
        }
        // swiftlint:enable avoid_all_header_fields
        if !responseHeaders.isEmpty {
            #if SDK_V10
            let sanitizedHeaders = HTTPHeaderSanitizer.sanitizeResponseHeaders(
                responseHeaders,
                options: options.dataCollection
            )
            responseContext["headers"] = sanitizedHeaders.headers
            responseContext["cookies"] = sanitizedHeaders.cookies
            #else
            responseContext["headers"] = HTTPHeaderSanitizer.sanitizeHeaders(responseHeaders)
            #endif
        }
        if sessionTask.countOfBytesReceived != 0 {
            responseContext["body_size"] = sessionTask.countOfBytesReceived
        }

        var context: [String: [String: Any]] = ["response": responseContext]
        if isGraphQLOperationTrackingEnabled,
           let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: sessionTask) {
            context["graphql"] = ["operation_name": operationName]
        }
        event.context = context

        _ = hub.captureErrorEvent(event: event)
    }

    private func containsStatusCode(_ statusCode: Int, options: Options) -> Bool {
        options.failedRequestStatusCodes.contains {
            statusCode >= $0.min && statusCode <= $0.max
        }
    }

    // MARK: - Breadcrumbs

    // swiftlint:disable:next function_body_length
    private func addBreadcrumb(for sessionTask: URLSessionTask, currentRequest: URLRequest, options: Options) {
        guard isNetworkBreadcrumbEnabled else {
            return
        }

        switch sessionTask.hasBreadcrumb {
        case .valid(let value) where value == true:
            // Session task already has a breadcrumb set
            return
        case .invalid(let invalid):
            SentrySDKLog.error("Found invalid type in url session task hasBreadcrumb: \(invalid)")
        default:
            break
        }

        guard let requestURL = currentRequest.url else {
            return
        }

        let responseStatusCode = urlResponseStatusCode(sessionTask.response)
        let breadcrumb = Breadcrumb(
            level: breadcrumbLevel(for: sessionTask, responseStatusCode: responseStatusCode),
            category: "http"
        )

        #if SDK_V10
        let urlComponents = UrlSanitized(URL: requestURL, options: options.dataCollection)
        #else
        let urlComponents = UrlSanitized(URL: requestURL)
        #endif

        breadcrumb.type = "http"
        var data: [String: Any] = [
            "request_body_size": sessionTask.countOfBytesSent,
            "response_body_size": sessionTask.countOfBytesReceived
        ]
        data["url"] = urlComponents.sanitizedUrl
        data["method"] = currentRequest.httpMethod

        if case .valid(let requestStart) = sessionTask.startDate {
            data["request_start"] = requestStart
        }

        if responseStatusCode != -1 {
            data["status_code"] = responseStatusCode
            data["reason"] = HTTPURLResponse.localizedString(forStatusCode: responseStatusCode)

            if isGraphQLOperationTrackingEnabled,
               let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: sessionTask) {
                data["graphql_operation_name"] = operationName
            }
        }

        if let query = urlComponents.query {
            data["http.query"] = query
        }
        if let fragment = urlComponents.fragment {
            data["http.fragment"] = fragment
        }

        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        synchronized(sessionTask) {
            if case .valid(let networkDetails) = sessionTask.networkDetails {
                data[SentryReplayNetworkDetails.replayNetworkDetailsKey] = networkDetails
            }
        }
        #endif

        breadcrumb.data = data
        SentrySDKInternal.addBreadcrumb(breadcrumb)
        sessionTask.setHasBreadcrumb(true)
    }

    // MARK: - Span status

    private func urlResponseStatusCode(_ response: URLResponse?) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    func status(for task: URLSessionTask, state: URLSessionTask.State) -> SentrySpanStatus {
        switch state {
        case .canceling:
            return .cancelled
        case .completed:
            if task.error != nil {
                return .unknownError
            }
            return spanStatus(forHTTPResponseStatusCode: urlResponseStatusCode(task.response))
        case .running:
            return .undefined
        // Suspended is not a terminal state: a task can be resumed or cancelled after being
        // suspended, so we don't map it to a span status.
        case .suspended:
            return .undefined
        @unknown default:
            return .undefined
        }
    }

    // https://develop.sentry.dev/sdk/event-payloads/span/
    private func spanStatus(forHTTPResponseStatusCode statusCode: Int) -> SentrySpanStatus {
        if (200..<300).contains(statusCode) {
            return .ok
        }

        switch statusCode {
        case 400:
            return .invalidArgument
        case 401:
            return .unauthenticated
        case 403:
            return .permissionDenied
        case 404:
            return .notFound
        case 409:
            return .aborted
        case 429:
            return .resourceExhausted
        case 500:
            return .internalError
        case 501:
            return .unimplemented
        case 503:
            return .unavailable
        case 504:
            return .deadlineExceeded
        default:
            return .undefined
        }
    }

    private func breadcrumbLevel(
        for sessionTask: URLSessionTask,
        responseStatusCode: Int
    ) -> SentryLevel {
        if sessionTask.error != nil || (500..<600).contains(responseStatusCode) {
            return .error
        }
        if (400..<500).contains(responseStatusCode) {
            return .warning
        }
        return .info
    }

    // MARK: - Session Replay network details

    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private func isNetworkDetailCaptureEnabled(for urlString: String, options: Options) -> Bool {
        options.sessionReplay.isNetworkDetailCaptureEnabled(for: urlString)
    }

    private func captureRequestDetails(
        for sessionTask: URLSessionTask,
        networkCaptureBodies: Bool,
        networkRequestHeaders: [String]
    ) {
        guard let request = sessionTask.currentRequest else {
            return
        }

        let details: SentryReplayNetworkDetails = synchronized(sessionTask) {
            if case .valid(let existingDetails) = sessionTask.networkDetails {
                return existingDetails
            }

            let newDetails = SentryReplayNetworkDetails(method: request.httpMethod ?? "GET")
            sessionTask.setNetworkDetails(newDetails)
            return newDetails
        }

        let rawBody = sessionTask.originalRequest?.httpBody ?? request.httpBody
        let requestSize = rawBody.map { NSNumber(value: $0.count) }

        details.setRequest(
            size: requestSize,
            bodyData: networkCaptureBodies ? rawBody : nil,
            contentType: request.value(forHTTPHeaderField: "content-type"),
            allHeaders: request.allHTTPHeaderFields,
            configuredHeaders: networkRequestHeaders
        )
    }
    #endif

    // MARK: - Helpers

    private func isTaskSupported(_ task: URLSessionTask) -> Bool {
        task is URLSessionDataTask || task is URLSessionDownloadTask || task is URLSessionUploadTask
    }

    private func isSentryRequest(_ url: URL, options: Options) -> Bool {
        guard let apiURL = options.parsedDsn?.url,
              let apiHost = apiURL.host,
              !apiURL.path.isEmpty else {
            return false
        }

        return url.host == apiHost && url.path.contains(apiURL.path)
    }

    private func addTraceWithoutTransaction(to task: URLSessionTask) {
        guard let options = hub.currentOptions else {
            return
        }

        let scope = hub.scope
        if let span = scope.span,
           let baggage = SentryTracer.getTracer(span)?.traceContext?.toBaggage() {
            SentryTracePropagation.addBaggageHeader(
                baggage,
                traceHeader: span.toTraceHeader(),
                propagateTraceparent: options.enablePropagateTraceparent,
                tracePropagationTargets: options.tracePropagationTargets,
                toRequest: task
            )
            return
        }

        guard let publicKey = options.parsedDsn?.url.user else {
            return
        }

        let baggage = Baggage(
            trace: scope.propagationContextTraceId,
            publicKey: publicKey,
            releaseName: options.releaseName,
            environment: options.environment,
            transaction: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: scope.replayId,
            orgId: options.effectiveOrgId
        )
        SentryTracePropagation.addBaggageHeader(
            baggage,
            traceHeader: scope.propagationContextTraceHeader,
            propagateTraceparent: options.enablePropagateTraceparent,
            tracePropagationTargets: options.tracePropagationTargets,
            toRequest: task
        )
    }
}
// swiftlint:enable type_body_length file_length
