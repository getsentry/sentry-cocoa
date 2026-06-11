// swiftlint:disable file_length missing_docs type_body_length
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCOptions) public final class SentryObjCOptions: NSObject {
    internal let wrapped: Options

    internal init(_ wrapped: Options) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Options()
    }

    @objc public var dsn: String? {
        get { wrapped.dsn }
        set { wrapped.dsn = newValue }
    }

    @objc public var debug: Bool {
        get { wrapped.debug }
        set { wrapped.debug = newValue }
    }

    @objc public var diagnosticLevel: SentryObjCLevel {
        get { SentryObjCLevel(wrapped.diagnosticLevel) }
        set { wrapped.diagnosticLevel = newValue.underlying }
    }

    @objc public var releaseName: String? {
        get { wrapped.releaseName }
        set { wrapped.releaseName = newValue }
    }

    @objc public var dist: String? {
        get { wrapped.dist }
        set { wrapped.dist = newValue }
    }

    @objc public var environment: String {
        get { wrapped.environment }
        set { wrapped.environment = newValue }
    }

    @objc public var enabled: Bool {
        get { wrapped.enabled }
        set { wrapped.enabled = newValue }
    }

    @objc public var shutdownTimeInterval: TimeInterval {
        get { wrapped.shutdownTimeInterval }
        set { wrapped.shutdownTimeInterval = newValue }
    }

    @objc public var enableCrashHandler: Bool {
        get { wrapped.enableCrashHandler }
        set { wrapped.enableCrashHandler = newValue }
    }

    #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc public var enableUncaughtNSExceptionReporting: Bool {
        get { wrapped.enableUncaughtNSExceptionReporting }
        set { wrapped.enableUncaughtNSExceptionReporting = newValue }
    }
    #endif

    #if !os(watchOS)
    @objc public var enableSigtermReporting: Bool {
        get { wrapped.enableSigtermReporting }
        set { wrapped.enableSigtermReporting = newValue }
    }
    #endif

    @objc public var maxBreadcrumbs: UInt {
        get { wrapped.maxBreadcrumbs }
        set { wrapped.maxBreadcrumbs = newValue }
    }

    @objc public var enableNetworkBreadcrumbs: Bool {
        get { wrapped.enableNetworkBreadcrumbs }
        set { wrapped.enableNetworkBreadcrumbs = newValue }
    }

    @objc public var maxCacheItems: UInt {
        get { wrapped.maxCacheItems }
        set { wrapped.maxCacheItems = newValue }
    }

    @objc public var beforeSend: ((SentryObjCEvent) -> SentryObjCEvent?)? {
        didSet {
            if let beforeSend = beforeSend {
                wrapped.beforeSend = { event in
                    guard let result = beforeSend(SentryObjCEvent(event)) else { return nil }
                    return result.wrapped
                }
            } else {
                wrapped.beforeSend = nil
            }
        }
    }

    @objc public var beforeSendSpan: ((SentryObjCSpan) -> SentryObjCSpan?)? {
        didSet {
            if let beforeSendSpan = beforeSendSpan {
                wrapped.beforeSendSpan = { span in
                    guard let result = beforeSendSpan(SentryObjCSpan(span)) else { return nil }
                    return result.wrapped
                }
            } else {
                wrapped.beforeSendSpan = nil
            }
        }
    }

    @objc public var enableLogs: Bool {
        get { wrapped.enableLogs }
        set { wrapped.enableLogs = newValue }
    }

    @objc public var beforeBreadcrumb: ((SentryObjCBreadcrumb) -> SentryObjCBreadcrumb?)? {
        didSet {
            if let beforeBreadcrumb = beforeBreadcrumb {
                wrapped.beforeBreadcrumb = { crumb in
                    guard let result = beforeBreadcrumb(SentryObjCBreadcrumb(crumb)) else { return nil }
                    return result.wrapped
                }
            } else {
                wrapped.beforeBreadcrumb = nil
            }
        }
    }

    @objc public var beforeSendLog: ((SentryObjCLog) -> SentryObjCLog?)? {
        didSet {
            if let beforeSendLog = beforeSendLog {
                wrapped.beforeSendLog = { log in
                    guard let result = beforeSendLog(SentryObjCLog(log)) else { return nil }
                    return result.wrapped
                }
            } else {
                wrapped.beforeSendLog = nil
            }
        }
    }

    @objc public var beforeSendMetric: ((SentryObjCMetric) -> SentryObjCMetric?)? {
        didSet {
            if let beforeSendMetric = beforeSendMetric {
                wrapped.beforeSendMetric = { metric in
                    guard let result = beforeSendMetric(SentryObjCMetric(metric)) else { return nil }
                    return result.metric
                }
            } else {
                wrapped.beforeSendMetric = nil
            }
        }
    }

    @objc public var beforeCaptureScreenshot: ((SentryObjCEvent) -> Bool)? {
        didSet {
            if let beforeCaptureScreenshot = beforeCaptureScreenshot {
                wrapped.beforeCaptureScreenshot = { event in
                    return beforeCaptureScreenshot(SentryObjCEvent(event))
                }
            } else {
                wrapped.beforeCaptureScreenshot = nil
            }
        }
    }

    @objc public var beforeCaptureViewHierarchy: ((SentryObjCEvent) -> Bool)? {
        didSet {
            if let beforeCaptureViewHierarchy = beforeCaptureViewHierarchy {
                wrapped.beforeCaptureViewHierarchy = { event in
                    return beforeCaptureViewHierarchy(SentryObjCEvent(event))
                }
            } else {
                wrapped.beforeCaptureViewHierarchy = nil
            }
        }
    }

    @available(*, deprecated, message: "Use onLastRunStatusDetermined instead.")
    @objc public var onCrashedLastRun: ((SentryObjCEvent) -> Void)? {
        didSet {
            if let onCrashedLastRun = onCrashedLastRun {
                wrapped.onCrashedLastRun = { event in
                    onCrashedLastRun(SentryObjCEvent(event))
                }
            } else {
                wrapped.onCrashedLastRun = nil
            }
        }
    }

    @objc public var onLastRunStatusDetermined: ((SentryObjCLastRunStatus, SentryObjCEvent?) -> Void)? {
        didSet {
            if let onLastRunStatusDetermined = onLastRunStatusDetermined {
                wrapped.onLastRunStatusDetermined = { status, event in
                    let wrappedEvent = event.map { SentryObjCEvent($0) }
                    onLastRunStatusDetermined(SentryObjCLastRunStatus(status), wrappedEvent)
                }
            } else {
                wrapped.onLastRunStatusDetermined = nil
            }
        }
    }

    @objc public var sampleRate: NSNumber? {
        get { wrapped.sampleRate }
        set { wrapped.sampleRate = newValue }
    }

    @objc public var enableAutoSessionTracking: Bool {
        get { wrapped.enableAutoSessionTracking }
        set { wrapped.enableAutoSessionTracking = newValue }
    }

    @objc public var enableGraphQLOperationTracking: Bool {
        get { wrapped.enableGraphQLOperationTracking }
        set { wrapped.enableGraphQLOperationTracking = newValue }
    }

    @objc public var enableWatchdogTerminationTracking: Bool {
        get { wrapped.enableWatchdogTerminationTracking }
        set { wrapped.enableWatchdogTerminationTracking = newValue }
    }

    @objc public var sessionTrackingIntervalMillis: UInt {
        get { wrapped.sessionTrackingIntervalMillis }
        set { wrapped.sessionTrackingIntervalMillis = newValue }
    }

    @objc public var attachStacktrace: Bool {
        get { wrapped.attachStacktrace }
        set { wrapped.attachStacktrace = newValue }
    }

    @objc public var attachAllThreads: Bool {
        get { wrapped.attachAllThreads }
        set { wrapped.attachAllThreads = newValue }
    }

    @objc public var maxAttachmentSize: UInt {
        get { wrapped.maxAttachmentSize }
        set { wrapped.maxAttachmentSize = newValue }
    }

    @objc public var sendDefaultPii: Bool {
        get { wrapped.sendDefaultPii }
        set { wrapped.sendDefaultPii = newValue }
    }

    @objc public var enableAutoPerformanceTracing: Bool {
        get { wrapped.enableAutoPerformanceTracing }
        set { wrapped.enableAutoPerformanceTracing = newValue }
    }

    @objc public var enablePersistingTracesWhenCrashing: Bool {
        get { wrapped.enablePersistingTracesWhenCrashing }
        set { wrapped.enablePersistingTracesWhenCrashing = newValue }
    }

    @objc public var initialScope: ((SentryObjCScope) -> SentryObjCScope) = { return $0 } {
        didSet {
            let initialScope = initialScope
            wrapped.initialScope = { scope in
                let result = initialScope(SentryObjCScope(scope))
                return result.wrapped
            }
        }
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

    @objc public var enableUIViewControllerTracing: Bool {
        get { wrapped.enableUIViewControllerTracing }
        set { wrapped.enableUIViewControllerTracing = newValue }
    }

    @objc public var attachScreenshot: Bool {
        get { wrapped.attachScreenshot }
        set { wrapped.attachScreenshot = newValue }
    }

    @objc public var attachViewHierarchy: Bool {
        get { wrapped.attachViewHierarchy }
        set { wrapped.attachViewHierarchy = newValue }
    }

    @objc public var reportAccessibilityIdentifier: Bool {
        get { wrapped.reportAccessibilityIdentifier }
        set { wrapped.reportAccessibilityIdentifier = newValue }
    }

    @objc public var enableUserInteractionTracing: Bool {
        get { wrapped.enableUserInteractionTracing }
        set { wrapped.enableUserInteractionTracing = newValue }
    }

    @objc public var idleTimeout: TimeInterval {
        get { wrapped.idleTimeout }
        set { wrapped.idleTimeout = newValue }
    }

    @objc public var enablePreWarmedAppStartTracing: Bool {
        get { wrapped.enablePreWarmedAppStartTracing }
        set { wrapped.enablePreWarmedAppStartTracing = newValue }
    }

    @objc public var enableReportNonFullyBlockingAppHangs: Bool {
        get { wrapped.enableReportNonFullyBlockingAppHangs }
        set { wrapped.enableReportNonFullyBlockingAppHangs = newValue }
    }

    #endif

    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

    @objc public var sessionReplay: SentryObjCReplayOptions {
        get { SentryObjCReplayOptions(wrapped.sessionReplay) }
        set { wrapped.sessionReplay = newValue.wrapped }
    }

    #endif

    @objc public var enableNetworkTracking: Bool {
        get { wrapped.enableNetworkTracking }
        set { wrapped.enableNetworkTracking = newValue }
    }

    @objc public var enableFileIOTracing: Bool {
        get { wrapped.enableFileIOTracing }
        set { wrapped.enableFileIOTracing = newValue }
    }

    @objc public var enableDataSwizzling: Bool {
        get { wrapped.enableDataSwizzling }
        set { wrapped.enableDataSwizzling = newValue }
    }

    @objc public var enableFileManagerSwizzling: Bool {
        get { wrapped.enableFileManagerSwizzling }
        set { wrapped.enableFileManagerSwizzling = newValue }
    }

    @objc public var tracesSampleRate: NSNumber? {
        get { wrapped.tracesSampleRate }
        set { wrapped.tracesSampleRate = newValue }
    }

    @objc public var tracesSampler: ((SentryObjCSamplingContext) -> NSNumber?)? {
        didSet {
            if let tracesSampler = tracesSampler {
                wrapped.tracesSampler = { context in
                    tracesSampler(SentryObjCSamplingContext(context))
                }
            } else {
                wrapped.tracesSampler = nil
            }
        }
    }

    @objc public var isTracingEnabled: Bool {
        wrapped.isTracingEnabled
    }

    @objc public var inAppIncludes: [String] {
        wrapped.inAppIncludes
    }

    @objc public func add(inAppInclude: String) {
        wrapped.add(inAppInclude: inAppInclude)
    }

    @objc public weak var urlSessionDelegate: URLSessionDelegate? {
        get { wrapped.urlSessionDelegate }
        set { wrapped.urlSessionDelegate = newValue }
    }

    @objc public var urlSession: URLSession? {
        get { wrapped.urlSession }
        set { wrapped.urlSession = newValue }
    }

    @objc public var enableSwizzling: Bool {
        get { wrapped.enableSwizzling }
        set { wrapped.enableSwizzling = newValue }
    }

    @objc public var swizzleClassNameExcludes: Set<String> {
        get { wrapped.swizzleClassNameExcludes }
        set { wrapped.swizzleClassNameExcludes = newValue }
    }

    @objc public var enableCoreDataTracing: Bool {
        get { wrapped.enableCoreDataTracing }
        set { wrapped.enableCoreDataTracing = newValue }
    }

    @objc public var sendClientReports: Bool {
        get { wrapped.sendClientReports }
        set { wrapped.sendClientReports = newValue }
    }

    @objc public var enableAppHangTracking: Bool {
        get { wrapped.enableAppHangTracking }
        set { wrapped.enableAppHangTracking = newValue }
    }

    @objc public var appHangTimeoutInterval: TimeInterval {
        get { wrapped.appHangTimeoutInterval }
        set { wrapped.appHangTimeoutInterval = newValue }
    }

    @objc public var enableAutoBreadcrumbTracking: Bool {
        get { wrapped.enableAutoBreadcrumbTracking }
        set { wrapped.enableAutoBreadcrumbTracking = newValue }
    }

    @objc public var enablePropagateTraceparent: Bool {
        get { wrapped.enablePropagateTraceparent }
        set { wrapped.enablePropagateTraceparent = newValue }
    }

    @objc public var tracePropagationTargets: [Any] {
        get { wrapped.tracePropagationTargets }
        set { wrapped.tracePropagationTargets = newValue }
    }

    @objc public var enableCaptureFailedRequests: Bool {
        get { wrapped.enableCaptureFailedRequests }
        set { wrapped.enableCaptureFailedRequests = newValue }
    }

    @objc public var failedRequestStatusCodes: [SentryObjCHttpStatusCodeRange] {
        get { wrapped.failedRequestStatusCodes.map { SentryObjCHttpStatusCodeRange($0) } }
        set { wrapped.failedRequestStatusCodes = newValue.map(\.wrapped) }
    }

    @objc public var failedRequestTargets: [Any] {
        get { wrapped.failedRequestTargets }
        set { wrapped.failedRequestTargets = newValue }
    }

    #if canImport(MetricKit) && !os(tvOS)

    @objc public var enableMetricKit: Bool {
        get { wrapped.enableMetricKit }
        set { wrapped.enableMetricKit = newValue }
    }

    @objc public var enableMetricKitRawPayload: Bool {
        get { wrapped.enableMetricKitRawPayload }
        set { wrapped.enableMetricKitRawPayload = newValue }
    }

    #endif

    @objc public var enableTimeToFullDisplayTracing: Bool {
        get { wrapped.enableTimeToFullDisplayTracing }
        set { wrapped.enableTimeToFullDisplayTracing = newValue }
    }

    @objc public var swiftAsyncStacktraces: Bool {
        get { wrapped.swiftAsyncStacktraces }
        set { wrapped.swiftAsyncStacktraces = newValue }
    }

    @objc public var cacheDirectoryPath: String {
        get { wrapped.cacheDirectoryPath }
        set { wrapped.cacheDirectoryPath = newValue }
    }

    @objc public var enableSpotlight: Bool {
        get { wrapped.enableSpotlight }
        set { wrapped.enableSpotlight = newValue }
    }

    @objc public var spotlightUrl: String {
        get { wrapped.spotlightUrl }
        set { wrapped.spotlightUrl = newValue }
    }

    @objc public var strictTraceContinuation: Bool {
        get { wrapped.strictTraceContinuation }
        set { wrapped.strictTraceContinuation = newValue }
    }

    @objc public var orgId: String? {
        get { wrapped.orgId }
        set { wrapped.orgId = newValue }
    }

    @objc public var experimental: SentryObjCExperimentalOptions {
        get { SentryObjCExperimentalOptions(wrapped.experimental) }
        set { wrapped.experimental = newValue.wrapped }
    }

    @objc public var enableMetrics: Bool {
        get { wrapped.enableMetrics }
        set { wrapped.enableMetrics = newValue }
    }
}
// swiftlint:enable file_length missing_docs type_body_length
