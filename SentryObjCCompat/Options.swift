// swiftlint:disable file_length
@_implementationOnly import Sentry
import Foundation

/// Configuration options for the Sentry SDK, exposed through the
/// `SentryObjCCompat` shim.
///
/// Every property forwards to a hidden `Sentry.Options` instance. The wrapper
/// only re-exposes properties whose types are primitives, Foundation types, or
/// other wrapped types from this module — properties that take SDK types
/// (`Event`, `Scope`, `Span`, etc.) are intentionally omitted in this first
/// cut and tagged `// TODO: wrap` below.
@objc(SOCSentryOptions)
public final class Options: NSObject {
    internal let wrapped: Sentry.Options

    internal init(_ wrapped: Sentry.Options) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.Options()
        super.init()
    }

    // MARK: - Core identification

    @objc public var dsn: String? {
        get { wrapped.dsn }
        set { wrapped.dsn = newValue }
    }

    @objc public var debug: Bool {
        get { wrapped.debug }
        set { wrapped.debug = newValue }
    }

    @objc public var diagnosticLevel: SentryLevel {
        get { SentryLevel(wrapped.diagnosticLevel) }
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

    // MARK: - Crash handling

    @objc public var enableCrashHandler: Bool {
        get { wrapped.enableCrashHandler }
        set { wrapped.enableCrashHandler = newValue }
    }

    #if os(macOS)
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

    // MARK: - Breadcrumbs

    @objc public var maxBreadcrumbs: UInt {
        get { wrapped.maxBreadcrumbs }
        set { wrapped.maxBreadcrumbs = newValue }
    }

    @objc public var enableNetworkBreadcrumbs: Bool {
        get { wrapped.enableNetworkBreadcrumbs }
        set { wrapped.enableNetworkBreadcrumbs = newValue }
    }

    @objc public var enableAutoBreadcrumbTracking: Bool {
        get { wrapped.enableAutoBreadcrumbTracking }
        set { wrapped.enableAutoBreadcrumbTracking = newValue }
    }

    // MARK: - Cache / transport

    @objc public var maxCacheItems: UInt {
        get { wrapped.maxCacheItems }
        set { wrapped.maxCacheItems = newValue }
    }

    @objc public var maxAttachmentSize: UInt {
        get { wrapped.maxAttachmentSize }
        set { wrapped.maxAttachmentSize = newValue }
    }

    @objc public var cacheDirectoryPath: String {
        get { wrapped.cacheDirectoryPath }
        set { wrapped.cacheDirectoryPath = newValue }
    }

    @objc public var sendClientReports: Bool {
        get { wrapped.sendClientReports }
        set { wrapped.sendClientReports = newValue }
    }

    // MARK: - Logs / metrics

    @objc public var enableLogs: Bool {
        get { wrapped.enableLogs }
        set { wrapped.enableLogs = newValue }
    }

    @objc public var enableMetrics: Bool {
        get { wrapped.enableMetrics }
        set { wrapped.enableMetrics = newValue }
    }

    // MARK: - Sampling

    @objc public var sampleRate: NSNumber? {
        get { wrapped.sampleRate }
        set { wrapped.sampleRate = newValue }
    }

    @objc public var tracesSampleRate: NSNumber? {
        get { wrapped.tracesSampleRate }
        set { wrapped.tracesSampleRate = newValue }
    }

    @objc public var isTracingEnabled: Bool {
        wrapped.isTracingEnabled
    }

    // MARK: - Session tracking

    @objc public var enableAutoSessionTracking: Bool {
        get { wrapped.enableAutoSessionTracking }
        set { wrapped.enableAutoSessionTracking = newValue }
    }

    @objc public var sessionTrackingIntervalMillis: UInt {
        get { wrapped.sessionTrackingIntervalMillis }
        set { wrapped.sessionTrackingIntervalMillis = newValue }
    }

    @objc public var enableWatchdogTerminationTracking: Bool {
        get { wrapped.enableWatchdogTerminationTracking }
        set { wrapped.enableWatchdogTerminationTracking = newValue }
    }

    // MARK: - Stack traces

    @objc public var attachStacktrace: Bool {
        get { wrapped.attachStacktrace }
        set { wrapped.attachStacktrace = newValue }
    }

    @objc public var attachAllThreads: Bool {
        get { wrapped.attachAllThreads }
        set { wrapped.attachAllThreads = newValue }
    }

    @objc public var sendDefaultPii: Bool {
        get { wrapped.sendDefaultPii }
        set { wrapped.sendDefaultPii = newValue }
    }

    // MARK: - Performance

    @objc public var enableAutoPerformanceTracing: Bool {
        get { wrapped.enableAutoPerformanceTracing }
        set { wrapped.enableAutoPerformanceTracing = newValue }
    }

    @objc public var enablePersistingTracesWhenCrashing: Bool {
        get { wrapped.enablePersistingTracesWhenCrashing }
        set { wrapped.enablePersistingTracesWhenCrashing = newValue }
    }

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

    @objc public var enableCoreDataTracing: Bool {
        get { wrapped.enableCoreDataTracing }
        set { wrapped.enableCoreDataTracing = newValue }
    }

    @objc public var enableGraphQLOperationTracking: Bool {
        get { wrapped.enableGraphQLOperationTracking }
        set { wrapped.enableGraphQLOperationTracking = newValue }
    }

    @objc public var enableTimeToFullDisplayTracing: Bool {
        get { wrapped.enableTimeToFullDisplayTracing }
        set { wrapped.enableTimeToFullDisplayTracing = newValue }
    }

    @objc public var swiftAsyncStacktraces: Bool {
        get { wrapped.swiftAsyncStacktraces }
        set { wrapped.swiftAsyncStacktraces = newValue }
    }

    // MARK: - UI-platform features

    #if os(iOS) || os(tvOS) || os(visionOS)
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

    // MARK: - In-app classification

    @objc public var inAppIncludes: [String] {
        wrapped.inAppIncludes
    }

    @objc public func add(inAppInclude: String) {
        wrapped.add(inAppInclude: inAppInclude)
    }

    // MARK: - HTTP

    @objc public var urlSessionDelegate: URLSessionDelegate? {
        get { wrapped.urlSessionDelegate }
        set { wrapped.urlSessionDelegate = newValue }
    }

    @objc public var urlSession: URLSession? {
        get { wrapped.urlSession }
        set { wrapped.urlSession = newValue }
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

    @objc public var failedRequestTargets: [Any] {
        get { wrapped.failedRequestTargets }
        set { wrapped.failedRequestTargets = newValue }
    }

    // MARK: - Swizzling

    @objc public var enableSwizzling: Bool {
        get { wrapped.enableSwizzling }
        set { wrapped.enableSwizzling = newValue }
    }

    @objc public var swizzleClassNameExcludes: Set<String> {
        get { wrapped.swizzleClassNameExcludes }
        set { wrapped.swizzleClassNameExcludes = newValue }
    }

    // MARK: - App hangs

    @objc public var enableAppHangTracking: Bool {
        get { wrapped.enableAppHangTracking }
        set { wrapped.enableAppHangTracking = newValue }
    }

    @objc public var appHangTimeoutInterval: TimeInterval {
        get { wrapped.appHangTimeoutInterval }
        set { wrapped.appHangTimeoutInterval = newValue }
    }

    // MARK: - MetricKit

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

    // MARK: - Spotlight / trace continuation

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

    // MARK: - DSN

    @objc public var parsedDsn: Dsn? {
        get { wrapped.parsedDsn.map(Dsn.init) }
        set { wrapped.parsedDsn = newValue?.wrapped }
    }

    // MARK: - Callbacks

    /// Block called for every captured event before it's sent. Return `nil` to drop.
    @objc public var beforeSend: ((Event) -> Event?)? {
        didSet {
            if let cb = beforeSend {
                wrapped.beforeSend = { underlying in
                    cb(Event(underlying))?.wrapped
                }
            } else {
                wrapped.beforeSend = nil
            }
        }
    }

    /// Block called for every span before it's sent. Return `nil` to drop.
    @objc public var beforeSendSpan: ((Span) -> Span?)? {
        didSet {
            if let cb = beforeSendSpan {
                wrapped.beforeSendSpan = { underlying in
                    cb(Span(underlying))?.wrapped
                }
            } else {
                wrapped.beforeSendSpan = nil
            }
        }
    }

    /// Block called for every breadcrumb before it's added. Return `nil` to drop.
    @objc public var beforeBreadcrumb: ((Breadcrumb) -> Breadcrumb?)? {
        didSet {
            if let cb = beforeBreadcrumb {
                wrapped.beforeBreadcrumb = { underlying in
                    cb(Breadcrumb(underlying))?.wrapped
                }
            } else {
                wrapped.beforeBreadcrumb = nil
            }
        }
    }

    /// Called once after init with the crash event captured during the previous run.
    @available(*, deprecated, message: "Use onLastRunStatusDetermined instead, which is called regardless of whether the app crashed.")
    @objc public var onCrashedLastRun: ((Event) -> Void)? {
        didSet {
            if let cb = onCrashedLastRun {
                wrapped.onCrashedLastRun = { underlying in
                    cb(Event(underlying))
                }
            } else {
                wrapped.onCrashedLastRun = nil
            }
        }
    }

    /// Called once after the crash status of the last program execution is known.
    @objc public var onLastRunStatusDetermined: ((SentryLastRunStatus, Event?) -> Void)? {
        didSet {
            if let cb = onLastRunStatusDetermined {
                wrapped.onLastRunStatusDetermined = { underlyingStatus, underlyingEvent in
                    cb(SentryLastRunStatus(underlyingStatus), underlyingEvent.map(Event.init))
                }
            } else {
                wrapped.onLastRunStatusDetermined = nil
            }
        }
    }

    /// Dynamic sampler for transactions.
    @objc public var tracesSampler: ((SamplingContext) -> NSNumber?)? {
        didSet {
            if let cb = tracesSampler {
                wrapped.tracesSampler = { underlying in
                    cb(SamplingContext(underlying))
                }
            } else {
                wrapped.tracesSampler = nil
            }
        }
    }

    /// Decide whether to capture a screenshot for a given event.
    @objc public var beforeCaptureScreenshot: ((Event) -> Bool)? {
        didSet {
            if let cb = beforeCaptureScreenshot {
                wrapped.beforeCaptureScreenshot = { underlying in
                    cb(Event(underlying))
                }
            } else {
                wrapped.beforeCaptureScreenshot = nil
            }
        }
    }

    /// Decide whether to capture a view hierarchy for a given event.
    @objc public var beforeCaptureViewHierarchy: ((Event) -> Bool)? {
        didSet {
            if let cb = beforeCaptureViewHierarchy {
                wrapped.beforeCaptureViewHierarchy = { underlying in
                    cb(Event(underlying))
                }
            } else {
                wrapped.beforeCaptureViewHierarchy = nil
            }
        }
    }

    /// Block used to construct the initial scope. Defaults to identity.
    @objc public var initialScope: (Scope) -> Scope {
        get {
            { scope in scope }
        }
        set {
            wrapped.initialScope = { underlying in
                newValue(Scope(underlying)).wrapped
            }
        }
    }

    // MARK: - Intentionally omitted in this pass
    //
    // TODO: wrap when SentryLog is wrapped: beforeSendLog
    // TODO: wrap when SentryViewScreenshotOptions is wrapped: screenshot
    // TODO: wrap when SentryReplayOptions is wrapped:         sessionReplay
    // TODO: wrap when HttpStatusCodeRange is wrapped:         failedRequestStatusCodes
    // TODO: wrap when SentryProfileOptions is wrapped:        configureProfiling, profiling
    // TODO: wrap when SentryExperimentalOptions is wrapped:   experimental
    // TODO: wrap when SentryUserFeedbackConfiguration is wrapped: configureUserFeedback
    // TODO: wrap when SentryMetric is wrapped:                beforeSendMetric
}
// swiftlint:enable file_length
