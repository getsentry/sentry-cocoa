@_implementationOnly import _SentryPrivate

struct Mapping {
    let fromOptions: (Options, inout SentryOptionsInternal) -> Void
    let fromOptionsInternal: (SentryOptionsInternal, inout Options) -> Void
    
    init<V>(optionsPath: WritableKeyPath<Options, V>, internalPath: WritableKeyPath<SentryOptionsInternal, V>) {
        self.fromOptions = { $1[keyPath: internalPath] = $0[keyPath: optionsPath] }
        self.fromOptionsInternal = { $1[keyPath: optionsPath] = $0[keyPath: internalPath] }
    }
}

#if os(macOS)
let macOSOnlyMapping = [Mapping(optionsPath: \.enableUncaughtNSExceptionReporting, internalPath: \.enableUncaughtNSExceptionReporting)]
#else
let macOSOnlyMapping = [Mapping]()
#endif

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
let uiKitMapping = [
    Mapping(optionsPath: \.enableUIViewControllerTracing, internalPath: \.enableUIViewControllerTracing),
    Mapping(optionsPath: \.attachScreenshot, internalPath: \.attachScreenshot),
    // Mapping(optionsPath: \.screenshot, internalPath: \.screenshot),
    Mapping(optionsPath: \.attachViewHierarchy, internalPath: \.attachViewHierarchy),
    Mapping(optionsPath: \.reportAccessibilityIdentifier, internalPath: \.reportAccessibilityIdentifier),
    Mapping(optionsPath: \.enableUserInteractionTracing, internalPath: \.enableUserInteractionTracing),
    Mapping(optionsPath: \.idleTimeout, internalPath: \.idleTimeout),
    Mapping(optionsPath: \.enablePreWarmedAppStartTracing, internalPath: \.enablePreWarmedAppStartTracing),
    Mapping(optionsPath: \.enableReportNonFullyBlockingAppHangs, internalPath: \.enableReportNonFullyBlockingAppHangs)
]
#else
let uiKitMapping = [Mapping]()
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
let sessionReplayMapping = [
    Mapping(optionsPath: \.sessionReplay, internalPath: \.sessionReplay)
]
#else
let sessionReplayMapping = [Mapping]()
#endif

#if !(os(watchOS) || os(tvOS) || os(visionOS))
let profilingMapping: [Mapping] = [
    // Mapping(optionsPath: \.configureProfiling, internalPath: \.configureProfiling)
]
#else
let profilingMapping = [Mapping]()
#endif

#if os(iOS) && !SENTRY_NO_UIKIT
let userFeedbackMapping = [Mapping(optionsPath: \.userFeedbackConfiguration, internalPath: \.userFeedbackConfiguration)]
#else
let userFeedbackMapping = [Mapping]()
#endif

#if canImport(MetricKit) && !os(tvOS) && !os(visionOS)
let metricKitMapping = [
    Mapping(optionsPath: \.enableMetricKit, internalPath: \.enableMetricKit),
    Mapping(optionsPath: \.enableMetricKitRawPayload, internalPath: \.enableMetricKitRawPayload)
]
#else
let metricKitMapping = [Mapping]()
#endif

#if os(watchOS)
let watchMapping = [Mapping]()
#else
let watchMapping = [Mapping(optionsPath: \.enableSigtermReporting, internalPath: \.enableSigtermReporting)]
#endif

let keyPathMapping = [
    Mapping(optionsPath: \.dsn, internalPath: \.dsn),
    Mapping(optionsPath: \.parsedDsn, internalPath: \.parsedDsn),
    Mapping(optionsPath: \.debug, internalPath: \.debug),
    //Mapping(optionsPath: \.diagnosticLevel, internalPath: \.diagnosticLevel),
    Mapping(optionsPath: \.releaseName, internalPath: \.releaseName),
    Mapping(optionsPath: \.dist, internalPath: \.dist),
    Mapping(optionsPath: \.environment, internalPath: \.environment),
    Mapping(optionsPath: \.enabled, internalPath: \.enabled),
    Mapping(optionsPath: \.shutdownTimeInterval, internalPath: \.shutdownTimeInterval),
    Mapping(optionsPath: \.enableCrashHandler, internalPath: \.enableCrashHandler),
    Mapping(optionsPath: \.maxBreadcrumbs, internalPath: \.maxBreadcrumbs),
    Mapping(optionsPath: \.enableNetworkBreadcrumbs, internalPath: \.enableNetworkBreadcrumbs),
    Mapping(optionsPath: \.maxCacheItems, internalPath: \.maxCacheItems),
    Mapping(optionsPath: \.beforeSend, internalPath: \.beforeSend),
    Mapping(optionsPath: \.beforeSendSpan, internalPath: \.beforeSendSpan),
    Mapping(optionsPath: \.enableLogs, internalPath: \.enableLogs),
    Mapping(optionsPath: \.beforeSendLog, internalPath: \.beforeSendLog),
    Mapping(optionsPath: \.beforeBreadcrumb, internalPath: \.beforeBreadcrumb),
    Mapping(optionsPath: \.beforeCaptureScreenshot, internalPath: \.beforeCaptureScreenshot),
    Mapping(optionsPath: \.beforeCaptureViewHierarchy, internalPath: \.beforeCaptureViewHierarchy),
    Mapping(optionsPath: \.onCrashedLastRun, internalPath: \.onCrashedLastRun),
    Mapping(optionsPath: \.sampleRate, internalPath: \.sampleRate),
    Mapping(optionsPath: \.enableAutoSessionTracking, internalPath: \.enableAutoSessionTracking),
    Mapping(optionsPath: \.enableGraphQLOperationTracking, internalPath: \.enableGraphQLOperationTracking),
    Mapping(optionsPath: \.enableWatchdogTerminationTracking, internalPath: \.enableWatchdogTerminationTracking),
    Mapping(optionsPath: \.sessionTrackingIntervalMillis, internalPath: \.sessionTrackingIntervalMillis),
    Mapping(optionsPath: \.attachStacktrace, internalPath: \.attachStacktrace),
    Mapping(optionsPath: \.maxAttachmentSize, internalPath: \.maxAttachmentSize),
    Mapping(optionsPath: \.sendDefaultPii, internalPath: \.sendDefaultPii),
    Mapping(optionsPath: \.enableAutoPerformanceTracing, internalPath: \.enableAutoPerformanceTracing),
    Mapping(optionsPath: \.enablePersistingTracesWhenCrashing, internalPath: \.enablePersistingTracesWhenCrashing),
    Mapping(optionsPath: \.initialScope, internalPath: \.initialScope),
    Mapping(optionsPath: \.enableNetworkTracking, internalPath: \.enableNetworkTracking),
    Mapping(optionsPath: \.enableFileIOTracing, internalPath: \.enableFileIOTracing),
    Mapping(optionsPath: \.enableDataSwizzling, internalPath: \.enableDataSwizzling),
    Mapping(optionsPath: \.enableFileManagerSwizzling, internalPath: \.enableFileManagerSwizzling),
    Mapping(optionsPath: \.tracesSampleRate, internalPath: \.tracesSampleRate),
    Mapping(optionsPath: \.tracesSampler, internalPath: \.tracesSampler),
    Mapping(optionsPath: \.inAppIncludes, internalPath: \.inAppIncludes),
    Mapping(optionsPath: \.inAppExcludes, internalPath: \.inAppExcludes),
    Mapping(optionsPath: \.urlSessionDelegate, internalPath: \.urlSessionDelegate),
    Mapping(optionsPath: \.urlSession, internalPath: \.urlSession),
    Mapping(optionsPath: \.enableSwizzling, internalPath: \.enableSwizzling),
    Mapping(optionsPath: \.swizzleClassNameExcludes, internalPath: \.swizzleClassNameExcludes),
    Mapping(optionsPath: \.enableCoreDataTracing, internalPath: \.enableCoreDataTracing),
    Mapping(optionsPath: \.sendClientReports, internalPath: \.sendClientReports),
    Mapping(optionsPath: \.enableAppHangTracking, internalPath: \.enableAppHangTracking),
    Mapping(optionsPath: \.appHangTimeoutInterval, internalPath: \.appHangTimeoutInterval),
    Mapping(optionsPath: \.enableAutoBreadcrumbTracking, internalPath: \.enableAutoBreadcrumbTracking),
    Mapping(optionsPath: \.enablePropagateTraceparent, internalPath: \.enablePropagateTraceparent),
    Mapping(optionsPath: \.tracePropagationTargets, internalPath: \.tracePropagationTargets),
    Mapping(optionsPath: \.enableCaptureFailedRequests, internalPath: \.enableCaptureFailedRequests),
    Mapping(optionsPath: \.failedRequestStatusCodes, internalPath: \.failedRequestStatusCodes),
    Mapping(optionsPath: \.failedRequestTargets, internalPath: \.failedRequestTargets),
    Mapping(optionsPath: \.enableTimeToFullDisplayTracing, internalPath: \.enableTimeToFullDisplayTracing),
    Mapping(optionsPath: \.swiftAsyncStacktraces, internalPath: \.swiftAsyncStacktraces),
    Mapping(optionsPath: \.cacheDirectoryPath, internalPath: \.cacheDirectoryPath),
    Mapping(optionsPath: \.enableSpotlight, internalPath: \.enableSpotlight),
    Mapping(optionsPath: \.spotlightUrl, internalPath: \.spotlightUrl),
    Mapping(optionsPath: \.experimental, internalPath: \.experimental)
] + macOSOnlyMapping + uiKitMapping + sessionReplayMapping + profilingMapping + userFeedbackMapping + metricKitMapping + watchMapping

extension SentryOptionsInternal {
    func toOptions() -> Options {
        var options = Options()
        keyPathMapping.forEach { mapping in
            mapping.fromOptionsInternal(self, &options)
        }
        return options
    }
}

extension Options {
    func toInternal() -> SentryOptionsInternal {
        var options = SentryOptionsInternal()
        keyPathMapping.forEach { mapping in
            mapping.fromOptions(self, &options)
        }
        return options
    }
}
