import Foundation
import ObjectiveC

extension Options {
    /// Initializes options from a dictionary, primarily for hybrid SDK configuration.
    @_spi(Private) public convenience init(dictionary: [String: Any]) throws {
        self.init()
        try apply(dictionary: dictionary)
    }

    /// Initializes options from a dictionary and reports parsing failures through an NSError pointer.
    @_spi(Private)
    @objc(initWithDictionary:didFailWithError:)
    public convenience init?(dictionary: [String: Any], didFailWithError error: NSErrorPointer) {
        self.init()
        do {
            try apply(dictionary: dictionary)
        } catch let caughtError {
            error?.pointee = caughtError as NSError
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func apply(dictionary: [String: Any]) throws {
        if let debug = boolValue(dictionary["debug"]) {
            self.debug = debug
        }

        if let diagnosticLevel = SentryLevel.fromName(dictionary["diagnosticLevel"] as? String) {
            self.diagnosticLevel = diagnosticLevel
        }

        if !(dictionary["dsn"] is NSNull) {
            let dsn = dictionary["dsn"] as? String ?? ""
            self.parsedDsn = try SentryDsn(string: dsn)
            self.dsn = dsn
        }

        if let release = dictionary["release"] as? String {
            self.releaseName = release
        }

        if let environment = dictionary["environment"] as? String {
            self.environment = environment
        }

        if let dist = dictionary["dist"] as? String {
            self.dist = dist
        }

        if let enabled = boolValue(dictionary["enabled"]) {
            self.enabled = enabled
        }

        if let shutdownTimeInterval = dictionary["shutdownTimeInterval"] as? NSNumber {
            self.shutdownTimeInterval = shutdownTimeInterval.doubleValue
        }

        if let enableCrashHandler = boolValue(dictionary["enableCrashHandler"]) {
            self.enableCrashHandler = enableCrashHandler
        }

        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        if let enableUncaughtNSExceptionReporting = boolValue(dictionary["enableUncaughtNSExceptionReporting"]) {
            self.enableUncaughtNSExceptionReporting = enableUncaughtNSExceptionReporting
        }
        #endif

        #if !os(watchOS)
        if let enableSigtermReporting = boolValue(dictionary["enableSigtermReporting"]) {
            self.enableSigtermReporting = enableSigtermReporting
        }
        #endif

        if let maxBreadcrumbs = dictionary["maxBreadcrumbs"] as? NSNumber {
            self.maxBreadcrumbs = maxBreadcrumbs.uintValue
        }

        #if !SDK_V10
        if let enableLogs = boolValue(dictionary["enableLogs"]) {
            self.enableLogs = enableLogs
        }
        #endif // !SDK_V10

        if let enableMetrics = boolValue(dictionary["enableMetrics"]) {
            self.enableMetrics = enableMetrics
        }

        if let enableNetworkBreadcrumbs = boolValue(dictionary["enableNetworkBreadcrumbs"]) {
            self.enableNetworkBreadcrumbs = enableNetworkBreadcrumbs
        }

        if let maxCacheItems = dictionary["maxCacheItems"] as? NSNumber {
            self.maxCacheItems = maxCacheItems.uintValue
        }

        if let cacheDirectoryPath = dictionary["cacheDirectoryPath"] as? String {
            self.cacheDirectoryPath = cacheDirectoryPath
        }

        setBlock(dictionary["beforeSend"], forKey: "beforeSend")
        setBlock(dictionary["beforeSendLog"], forKey: "beforeSendLog")
        setBlock(dictionary["beforeSendSpan"], forKey: "beforeSendSpan")
        setBlock(dictionary["beforeBreadcrumb"], forKey: "beforeBreadcrumb")
        setBlock(dictionary["beforeCaptureScreenshot"], forKey: "beforeCaptureScreenshot")
        setBlock(dictionary["beforeCaptureViewHierarchy"], forKey: "beforeCaptureViewHierarchy")

        #if !SDK_V10
        setBlock(dictionary["onCrashedLastRun"], forKey: "onCrashedLastRun")
        #endif

        setBlock(dictionary["onLastRunStatusDetermined"], forKey: "onLastRunStatusDetermined")

        if let sampleRate = dictionary["sampleRate"] as? NSNumber {
            self.sampleRate = sampleRate
        }

        if let enableAutoSessionTracking = boolValue(dictionary["enableAutoSessionTracking"]) {
            self.enableAutoSessionTracking = enableAutoSessionTracking
        }

        if let enableGraphQLOperationTracking = boolValue(dictionary["enableGraphQLOperationTracking"]) {
            self.enableGraphQLOperationTracking = enableGraphQLOperationTracking
        }

        if let enableWatchdogTerminationTracking = boolValue(dictionary["enableWatchdogTerminationTracking"]) {
            self.enableWatchdogTerminationTracking = enableWatchdogTerminationTracking
        }

        if let swiftAsyncStacktraces = boolValue(dictionary["swiftAsyncStacktraces"]) {
            self.swiftAsyncStacktraces = swiftAsyncStacktraces
        }

        if let sessionTrackingIntervalMillis = dictionary["sessionTrackingIntervalMillis"] as? NSNumber {
            self.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis.uintValue
        }

        if let attachStacktrace = boolValue(dictionary["attachStacktrace"]) {
            self.attachStacktrace = attachStacktrace
        }

        if let maxAttachmentSize = dictionary["maxAttachmentSize"] as? NSNumber {
            self.maxAttachmentSize = maxAttachmentSize.uintValue
        }

#if !SDK_V10
        if let sendDefaultPii = boolValue(dictionary["sendDefaultPii"]) {
            self.sendDefaultPii = sendDefaultPii
        }
#endif // !SDK_V10

        if let enableAutoPerformanceTracing = boolValue(dictionary["enableAutoPerformanceTracing"]) {
            self.enableAutoPerformanceTracing = enableAutoPerformanceTracing
        }

        if let enablePersistingTracesWhenCrashing = boolValue(dictionary["enablePersistingTracesWhenCrashing"]) {
            self.enablePersistingTracesWhenCrashing = enablePersistingTracesWhenCrashing
        }

        if let enableCaptureFailedRequests = boolValue(dictionary["enableCaptureFailedRequests"]) {
            self.enableCaptureFailedRequests = enableCaptureFailedRequests
        }

        if let enableTimeToFullDisplayTracing = boolValue(dictionary["enableTimeToFullDisplayTracing"]) {
            self.enableTimeToFullDisplayTracing = enableTimeToFullDisplayTracing
        }

        setBlock(dictionary["initialScope"], forKey: "initialScope")

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if let enableUIViewControllerTracing = boolValue(dictionary["enableUIViewControllerTracing"]) {
            self.enableUIViewControllerTracing = enableUIViewControllerTracing
        }

        if let attachScreenshot = boolValue(dictionary["attachScreenshot"]) {
            self.attachScreenshot = attachScreenshot
        }

        if let attachViewHierarchy = boolValue(dictionary["attachViewHierarchy"]) {
            self.attachViewHierarchy = attachViewHierarchy
        }

        if let reportAccessibilityIdentifier = boolValue(dictionary["reportAccessibilityIdentifier"]) {
            self.reportAccessibilityIdentifier = reportAccessibilityIdentifier
        }

        if let enableUserInteractionTracing = boolValue(dictionary["enableUserInteractionTracing"]) {
            self.enableUserInteractionTracing = enableUserInteractionTracing
        }

        if let idleTimeout = dictionary["idleTimeout"] as? NSNumber {
            self.idleTimeout = idleTimeout.doubleValue
        }

        if let enablePreWarmedAppStartTracing = boolValue(dictionary["enablePreWarmedAppStartTracing"]) {
            self.enablePreWarmedAppStartTracing = enablePreWarmedAppStartTracing
        }

        if let enableReportNonFullyBlockingAppHangs = boolValue(dictionary["enableReportNonFullyBlockingAppHangs"]) {
            self.enableReportNonFullyBlockingAppHangs = enableReportNonFullyBlockingAppHangs
        }
        #endif

        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        if let sessionReplay = dictionary["sessionReplay"] as? [String: Any] {
            self.sessionReplay = SentryReplayOptions(dictionary: sessionReplay)
        }
        #endif

        if let enableAppHangTracking = boolValue(dictionary["enableAppHangTracking"]) {
            self.enableAppHangTracking = enableAppHangTracking
        }

        if let appHangTimeoutInterval = dictionary["appHangTimeoutInterval"] as? NSNumber {
            self.appHangTimeoutInterval = appHangTimeoutInterval.doubleValue
        }

        if let enableNetworkTracking = boolValue(dictionary["enableNetworkTracking"]) {
            self.enableNetworkTracking = enableNetworkTracking
        }

        if let enableFileIOTracing = boolValue(dictionary["enableFileIOTracing"]) {
            self.enableFileIOTracing = enableFileIOTracing
        }

        if let tracesSampleRate = dictionary["tracesSampleRate"] as? NSNumber {
            self.tracesSampleRate = tracesSampleRate
        }

        setBlock(dictionary["tracesSampler"], forKey: "tracesSampler")

        if let inAppIncludes = dictionary["inAppIncludes"] as? [Any] {
            inAppIncludes.compactMap { $0 as? String }.forEach { add(inAppInclude: $0) }
        }

        if let urlSession = dictionary["urlSession"] as? URLSession {
            self.urlSession = urlSession
        }

        if let urlSessionDelegate = dictionary["urlSessionDelegate"] as? URLSessionDelegate {
            self.urlSessionDelegate = urlSessionDelegate
        }

        if let enableSwizzling = boolValue(dictionary["enableSwizzling"]) {
            self.enableSwizzling = enableSwizzling
        }

        if let swizzleClassNameExcludes = dictionary["swizzleClassNameExcludes"] as? Set<AnyHashable> {
            self.swizzleClassNameExcludes = Set(swizzleClassNameExcludes.compactMap { $0 as? String })
        }

        if let enableCoreDataTracing = boolValue(dictionary["enableCoreDataTracing"]) {
            self.enableCoreDataTracing = enableCoreDataTracing
        }

        if let sendClientReports = boolValue(dictionary["sendClientReports"]) {
            self.sendClientReports = sendClientReports
        }

        if let enableAutoBreadcrumbTracking = boolValue(dictionary["enableAutoBreadcrumbTracking"]) {
            self.enableAutoBreadcrumbTracking = enableAutoBreadcrumbTracking
        }

        if let enablePropagateTraceparent = boolValue(dictionary["enablePropagateTraceparent"]) {
            self.enablePropagateTraceparent = enablePropagateTraceparent
        }

        if let tracePropagationTargets = dictionary["tracePropagationTargets"] as? [Any] {
            self.tracePropagationTargets = tracePropagationTargets
        }

        if let failedRequestStatusCodes = dictionary["failedRequestStatusCodes"] as? [HttpStatusCodeRange] {
            self.failedRequestStatusCodes = failedRequestStatusCodes
        }

        if let failedRequestTargets = dictionary["failedRequestTargets"] as? [Any] {
            self.failedRequestTargets = failedRequestTargets
        }

        #if canImport(MetricKit) && !os(tvOS)
        if let enableMetricKit = boolValue(dictionary["enableMetricKit"]) {
            self.enableMetricKit = enableMetricKit
        }

        if let enableMetricKitRawPayload = boolValue(dictionary["enableMetricKitRawPayload"]) {
            self.enableMetricKitRawPayload = enableMetricKitRawPayload
        }
        #endif

        if let strictTraceContinuation = boolValue(dictionary["strictTraceContinuation"]) {
            self.strictTraceContinuation = strictTraceContinuation
        }

        if let orgId = dictionary["orgId"] as? String {
            self.orgId = orgId
        }

        if let enableSpotlight = boolValue(dictionary["enableSpotlight"]) {
            self.enableSpotlight = enableSpotlight
        }

        if let spotlightUrl = dictionary["spotlightUrl"] as? String {
            self.spotlightUrl = spotlightUrl
        }

        #if SDK_V10
        if let dataCollection = dictionary["dataCollection"] as? [String: Any] {
            self.dataCollection = SentryDataCollection.Options(dictionary: dataCollection)
        }
        #endif // SDK_V10

        if let enableMemoryIntrospection = boolValue(dictionary["enableMemoryIntrospection"]) {
            self.enableMemoryIntrospection = enableMemoryIntrospection
        }
    }

    private func boolValue(_ value: Any?) -> Bool? {
        guard let value, !isNull(value) else { return nil }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        if let string = value as? NSString {
            return string.boolValue
        }

        return false
    }

    private func setBlock(_ value: Any?, forKey key: String) {
        guard isBlock(value) else { return }
        setValue(value, forKey: key)
    }

    private func isBlock(_ value: Any?) -> Bool {
        guard let object = value as AnyObject?, !isNull(value) else { return false }
        return object.isKind(of: blockClass)
    }

    private func isNull(_ value: Any?) -> Bool {
        value == nil || value is NSNull
    }
}

private let blockClass: AnyClass = {
    let block: @convention(block) () -> Void = { }
    var candidate: AnyClass = type(of: block as AnyObject)
    while let superclass = class_getSuperclass(candidate), superclass != NSObject.self {
        candidate = superclass
    }
    return candidate
}()
