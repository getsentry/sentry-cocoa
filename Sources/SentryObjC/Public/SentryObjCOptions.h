// swiftlint:disable file_length
#import <Foundation/Foundation.h>
#import "SentryObjCDefines.h"
#import "SentryObjCLastRunStatus.h"
#import "SentryObjCLevel.h"

@class SentryObjCBreadcrumb;
@class SentryObjCEvent;
@class SentryObjCExperimentalOptions;
@class SentryObjCHttpStatusCodeRange;
@class SentryObjCReplayOptions;
@class SentryObjCSamplingContext;
@class SentryObjCScope;
@class SentryObjCSpan;

NS_ASSUME_NONNULL_BEGIN

/// Configuration options for the Sentry SDK.
@interface SentryObjCOptions : NSObject

/**
 * The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
 * not send any events.
 */
@property (nonatomic, copy, nullable) NSString *dsn;

/**
 * Turns debug mode on or off. If debug is enabled the SDK will attempt to print out useful
 * debugging information if something goes wrong.
 * @note Default is @c NO.
 */
@property (nonatomic) BOOL debug;

/**
 * Minimum log level to be used if debug is enabled.
 * @note Default is @c SentryObjCLevelDebug.
 */
@property (nonatomic) SentryObjCLevel diagnosticLevel;

/**
 * This property will be filled before the event is sent.
 * Typically follows the format: @c BundleIdentifier@Version+Build.
 */
@property (nonatomic, copy, nullable) NSString *releaseName;

/**
 * The distribution of the application.
 * Distributions are used to disambiguate build or deployment variants of the same release of an
 * application. For example, the dist can be the build number of an Xcode build.
 */
@property (nonatomic, copy, nullable) NSString *dist;

/**
 * The environment used for events if no environment is set on the current scope.
 * @note Default value is @c "production".
 */
@property (nonatomic, copy) NSString *environment;

/**
 * Specifies whether this SDK should send events to Sentry. If set to @c NO, events will be
 * dropped in the client and not sent to Sentry.
 * @note Default is @c YES.
 */
@property (nonatomic) BOOL enabled;

/// Controls the flush duration when calling @c SentryObjCSDK.close.
@property (nonatomic) NSTimeInterval shutdownTimeInterval;

/**
 * When enabled, the SDK sends crashes to Sentry.
 * @note Disabling this feature disables watchdog termination tracking, because it would falsely
 * report every crash as watchdog termination.
 * @note Default value is @c YES.
 * @note Crash reporting is automatically disabled if a debugger is attached.
 */
@property (nonatomic) BOOL enableCrashHandler;

/**
 * How many breadcrumbs do you want to keep in memory?
 * @note Default is 100.
 */
@property (nonatomic) NSUInteger maxBreadcrumbs;

/**
 * When enabled, the SDK adds breadcrumbs for each network request. As this feature uses
 * swizzling, disabling @c enableSwizzling also disables this feature.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableNetworkBreadcrumbs;

/**
 * The maximum number of envelopes to keep in cache.
 * @note Default is 30.
 */
@property (nonatomic) NSUInteger maxCacheItems;

/// This block can be used to modify the event before it will be serialized and sent.
@property (nonatomic, copy, nullable) SentryObjCEvent *_Nullable (^beforeSend)(SentryObjCEvent *);

/**
 * Use this callback to drop or modify a span before the SDK sends it to Sentry.
 * Return @c nil to drop the span.
 */
@property (nonatomic, copy, nullable) SentryObjCSpan *_Nullable (^beforeSendSpan)(SentryObjCSpan *);

/**
 * When enabled, the SDK sends logs to Sentry. Logs can be captured using the
 * @c SentryObjCSDK.logger API, which provides structured logging with attributes.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL enableLogs;

/// This block can be used to modify the breadcrumb before it will be serialized and sent.
@property (nonatomic, copy, nullable) SentryObjCBreadcrumb *_Nullable (^beforeBreadcrumb)
    (SentryObjCBreadcrumb *);

/**
 * You can use this callback to decide if the SDK should capture a screenshot or not.
 * Return @c YES if the SDK should capture a screenshot, return @c NO if not. This callback
 * doesn't work for crashes.
 */
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureScreenshot)(SentryObjCEvent *);

/**
 * You can use this callback to decide if the SDK should capture a view hierarchy or not.
 * Return @c YES if the SDK should capture a view hierarchy, return @c NO if not. This callback
 * doesn't work for crashes.
 */
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureViewHierarchy)(SentryObjCEvent *);

/**
 * A block called shortly after the initialization of the SDK when the last program execution
 * terminated with a crash.
 * @note This callback is only executed once during the entire run of the program.
 * @warning It is not guaranteed that this is called on the main thread.
 * @deprecated Use @c onLastRunStatusDetermined instead.
 */
@property (nonatomic, copy, nullable) void (^onCrashedLastRun)(SentryObjCEvent *)
    __attribute__((deprecated("Use onLastRunStatusDetermined instead.")));

/**
 * A block called shortly after the initialization of the SDK when the crash status of the
 * last program execution has been determined. This callback is invoked regardless of whether the
 * app crashed or not.
 * @note This callback is only executed once per SDK start lifecycle.
 * @warning It is not guaranteed that this is called on the main thread.
 */
@property (nonatomic, copy, nullable) void (^onLastRunStatusDetermined)
    (SentryObjCLastRunStatus, SentryObjCEvent *_Nullable);

/**
 * Indicates the percentage of events being sent to Sentry.
 * Specifying 0 discards all events, 1.0 or @c nil sends all events, 0.01 collects 1% of
 * all events.
 * @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets
 * it to the default of 1.0.
 * @note The default is 1.
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * Whether to enable automatic session tracking or not.
 * @note Default is @c YES.
 */
@property (nonatomic) BOOL enableAutoSessionTracking;

/**
 * Whether to attach the top level @c operationName node of HTTP JSON requests to HTTP
 * breadcrumbs.
 * @note Default is @c NO.
 */
@property (nonatomic) BOOL enableGraphQLOperationTracking;

/**
 * Whether to enable Watchdog Termination tracking or not.
 * @note This feature requires the crash handler being enabled, otherwise it would falsely report
 * every crash as watchdog termination.
 * @note Default is @c YES.
 */
@property (nonatomic) BOOL enableWatchdogTerminationTracking;

/**
 * The interval to end a session after the App goes to the background.
 * @note The default is 30000 milliseconds (30 seconds).
 */
@property (nonatomic) NSUInteger sessionTrackingIntervalMillis;

/**
 * When enabled, stack traces are automatically attached to all messages logged. Stack traces are
 * always attached to exceptions but when this is set stack traces are also sent with messages.
 * Stack traces are only attached for the current thread.
 * @note This feature is enabled by default.
 */
@property (nonatomic) BOOL attachStacktrace;

/**
 * When enabled, all threads are attached with full stack traces to all captured events.
 * This requires suspending all threads briefly to collect their stack traces.
 * When disabled (the default), only the current thread gets a stack trace.
 * @note @c attachStacktrace must also be enabled for this to have any effect.
 * @note Default is @c NO.
 */
@property (nonatomic) BOOL attachAllThreads;

/**
 * The maximum size for each attachment in bytes.
 * @note Default is 200 MiB (200 * 1024 * 1024 bytes).
 * @note Please also check the maximum attachment size of relay to make sure your attachments
 * don't get discarded there.
 */
@property (nonatomic) NSUInteger maxAttachmentSize;

/**
 * When enabled, the SDK sends personal identifiable information along with events.
 * @note The default is @c NO.
 */
@property (nonatomic) BOOL sendDefaultPii;

/**
 * When enabled, the SDK tracks performance for UIViewController subclasses and HTTP requests
 * automatically. It also measures the app start and slow and frozen frames.
 * @note The default is @c YES.
 * @note Performance Monitoring must be enabled for this flag to take effect.
 */
@property (nonatomic) BOOL enableAutoPerformanceTracing;

/**
 * When enabled, the SDK finishes the ongoing transaction bound to the scope and links them to
 * the crash event when your app crashes. The SDK skips adding profiles to increase the chance
 * of keeping the transaction.
 * @warning This is an experimental feature and may still have bugs.
 * @note The default is @c NO.
 */
@property (nonatomic) BOOL enablePersistingTracesWhenCrashing;

/**
 * A block that configures the initial scope when starting the SDK.
 * The block receives a suggested default scope. You can either configure and return this,
 * or create your own scope instead.
 * @note The default simply returns the passed in scope.
 */
@property (nonatomic, copy) SentryObjCScope * (^initialScope)(SentryObjCScope *);

/**
 * When enabled, the SDK tracks performance for HTTP requests if auto performance tracking and
 * @c enableSwizzling are enabled.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableNetworkTracking;

/**
 * When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
 * performance tracking and @c enableSwizzling are enabled.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableFileIOTracing;

/**
 * When enabled, the SDK tracks performance for data read and write operations with NSData if
 * auto performance tracking and @c enableSwizzling are enabled.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableDataSwizzling;

/**
 * When enabled, the SDK tracks performance for file IO operations with NSFileManager if auto
 * performance tracking and @c enableSwizzling are enabled.
 * @note The default is @c NO.
 */
@property (nonatomic) BOOL enableFileManagerSwizzling;

/**
 * Indicates the percentage of the tracing data that is collected.
 * Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
 * @c 0.01 collects 1% of all trace data.
 * @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets
 * it to the default.
 * @note The default is @c 0.
 */
@property (nonatomic, strong, nullable) NSNumber *tracesSampleRate;

/**
 * A callback to a user defined traces sampler function.
 * Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
 * @c 0.01 collects 1% of all trace data.
 * @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets
 * it to the default of @c 0.
 */
@property (nonatomic, copy, nullable) NSNumber *_Nullable (^tracesSampler)
    (SentryObjCSamplingContext *);

/**
 * If tracing is enabled or not.
 * @c YES if @c tracesSampleRate is > @c 0 and <= @c 1 or a @c tracesSampler is set,
 * otherwise @c NO.
 */
@property (nonatomic, readonly) BOOL isTracingEnabled;

/**
 * A list of string prefixes of framework names that belong to the app.
 * @note By default, this contains @c CFBundleExecutable to mark it as "in-app".
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppIncludes;

/**
 * Set as delegate on the URLSession used for all network data-transfer tasks performed by
 * Sentry. The SDK ignores this option when using @c urlSession.
 */
@property (nonatomic, weak, nullable) id<NSURLSessionDelegate> urlSessionDelegate;

/**
 * Use this property so the transport uses this URLSession with your configuration for sending
 * requests to Sentry. If not set, the SDK will create a new URLSession with an ephemeral
 * configuration.
 */
@property (nonatomic, strong, nullable) NSURLSession *urlSession;

/**
 * Whether the SDK should use swizzling or not.
 * When turned off the following features are disabled: breadcrumbs for touch events and
 * navigation with UIViewControllers, automatic instrumentation for UIViewControllers,
 * automatic instrumentation for HTTP requests, automatic instrumentation for file IO with
 * NSData, and automatically added sentry-trace header to HTTP requests for distributed tracing.
 * @note Default is @c YES.
 */
@property (nonatomic) BOOL enableSwizzling;

/**
 * A set of class names to ignore for swizzling.
 * The SDK checks if a class name of a class to swizzle contains a class name of this set.
 * @note Default is an empty set.
 */
@property (nonatomic, copy) NSSet<NSString *> *swizzleClassNameExcludes;

/**
 * When enabled, the SDK tracks the performance of Core Data operations. It requires enabling
 * performance monitoring.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableCoreDataTracing;

/**
 * Whether to send client reports, which contain statistics about discarded events.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL sendClientReports;

/**
 * When enabled, the SDK tracks when the application stops responding for a specific amount of
 * time defined by the @c appHangTimeoutInterval option.
 * @note The default is @c YES.
 * @note App Hang tracking is automatically disabled if a debugger is attached.
 */
@property (nonatomic) BOOL enableAppHangTracking;

/**
 * The minimum amount of time an app should be unresponsive to be classified as an App Hang.
 * @note The actual amount may be a little longer.
 * @note Avoid using values lower than 100ms, which may cause a lot of app hang events being
 * transmitted.
 * @note The default value is 2 seconds.
 */
@property (nonatomic) NSTimeInterval appHangTimeoutInterval;

/**
 * When enabled, the SDK adds breadcrumbs for various system events.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableAutoBreadcrumbTracking;

/**
 * When enabled, the SDK propagates the W3C Trace Context HTTP header traceparent on outgoing
 * HTTP requests.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL enablePropagateTraceparent;

/**
 * An array of hosts or regexes that determines if outgoing HTTP requests will get extra
 * @c trace_id and @c baggage headers added.
 * This array can contain instances of @c NSString which should match the URL (using
 * @c contains), and instances of @c NSRegularExpression, which will be used to check the
 * whole URL.
 * @note The default value adds the header to all outgoing requests.
 */
@property (nonatomic, copy) NSArray *tracePropagationTargets;

/**
 * When enabled, the SDK captures HTTP Client errors.
 * @note This feature requires @c enableSwizzling enabled as well.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableCaptureFailedRequests;

/**
 * The SDK will only capture HTTP Client errors if the HTTP Response status code is within the
 * defined range.
 * @note Defaults to 500-599.
 */
@property (nonatomic, copy) NSArray<SentryObjCHttpStatusCodeRange *> *failedRequestStatusCodes;

/**
 * An array of hosts or regexes that determines if HTTP Client errors will be automatically
 * captured.
 * This array can contain instances of @c NSString which should match the URL (using
 * @c contains), and instances of @c NSRegularExpression, which will be used to check the
 * whole URL.
 * @note The default value automatically captures HTTP Client errors of all outgoing requests.
 */
@property (nonatomic, copy) NSArray *failedRequestTargets;

/**
 * By enabling this, every UIViewController tracing transaction will wait for a call to
 * @c reportFullyDisplayed.
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL enableTimeToFullDisplayTracing;

/**
 * Stitches the call to Swift Async functions in one consecutive stack trace.
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL swiftAsyncStacktraces;

/**
 * The path to store SDK data, like events, transactions, profiles, raw crash data, etc.
 * We recommend only changing this when the default, e.g., in security environments, can't be
 * accessed.
 * @note The default is @c NSCachesDirectory.
 */
@property (nonatomic, copy) NSString *cacheDirectoryPath;

/**
 * Whether to enable Spotlight for local development.
 * @note Only set this option to @c YES while developing, not in production!
 * @note Default is @c NO.
 */
@property (nonatomic) BOOL enableSpotlight;

/**
 * The Spotlight URL.
 * @note Defaults to @c http://localhost:8969/stream.
 */
@property (nonatomic, copy) NSString *spotlightUrl;

/**
 * If set to @c YES, the SDK will only continue a trace if the organization ID of the incoming
 * trace found in the baggage header matches the organization ID of the current Sentry client.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL strictTraceContinuation;

/**
 * The organization ID for your Sentry project.
 * The SDK will try to extract the organization ID from the DSN. If it cannot be found, or if
 * you need to override it, you can provide the ID with this option.
 */
@property (nonatomic, copy, nullable) NSString *orgId;

/// Options for experimental features that are subject to change.
@property (nonatomic, strong) SentryObjCExperimentalOptions *experimental;

/**
 * When enabled, the SDK sends metrics to Sentry.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableMetrics;

#if (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT

/**
 * When enabled, the SDK tracks performance for UIViewController subclasses.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableUIViewControllerTracing;

/**
 * Automatically attaches a screenshot when capturing an error or exception.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL attachScreenshot;

/**
 * Automatically attaches a textual representation of the view hierarchy when capturing an
 * error event.
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL attachViewHierarchy;

/**
 * If enabled, view hierarchy attachment will contain view @c accessibilityIdentifier.
 * Set it to @c NO if your project uses @c accessibilityIdentifier for PII.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL reportAccessibilityIdentifier;

/**
 * When enabled, the SDK creates transactions for UI events like button clicks, switch toggles,
 * and other UI elements that use UIControl @c sendAction:to:forEvent:.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableUserInteractionTracing;

/**
 * How long an idle transaction waits for new children after all its child spans finished.
 * Only UI event transactions are idle transactions.
 * @note The default is 3 seconds.
 */
@property (nonatomic) NSTimeInterval idleTimeout;

/**
 * Report pre-warmed app starts by dropping the first app start spans if pre-warming paused
 * during these steps. This approach will shorten the app start duration, but it represents the
 * duration a user has to wait after clicking the app icon until the app is responsive.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enablePreWarmedAppStartTracing;

/**
 * When enabled, the SDK reports non-fully-blocking app hangs. A non-fully-blocking app hang is
 * when the app appears stuck to the user but can still render a few frames.
 * @note The default is @c YES.
 */
@property (nonatomic) BOOL enableReportNonFullyBlockingAppHangs;

#endif

#if (TARGET_OS_IOS || TARGET_OS_TV) && SENTRY_OBJC_HAS_UIKIT

/// Configuration options for Session Replay.
@property (nonatomic, strong) SentryObjCReplayOptions *sessionReplay;

#endif

#if TARGET_OS_OSX && SENTRY_OBJC_HAS_UIKIT

/**
 * When enabled, the SDK reports uncaught NSExceptions via @c NSSetUncaughtExceptionHandler.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableUncaughtNSExceptionReporting;

#endif

#if !TARGET_OS_WATCH

/**
 * When enabled, the SDK reports SIGTERM signals.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL enableSigtermReporting;

#endif

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

/**
 * When enabled, the SDK collects @c MXDiskWriteExceptionDiagnostic, @c MXCPUExceptionDiagnostic,
 * and @c MXHangDiagnostic from MetricKit and converts them to Sentry events.
 * @note Default value is @c YES.
 */
@property (nonatomic) BOOL enableMetricKit;

/**
 * When enabled, the SDK sends the raw MXDiagnosticPayload as an attachment to Sentry.
 * @note Default value is @c NO.
 */
@property (nonatomic) BOOL enableMetricKitRawPayload;

#endif

- (instancetype)init;

/**
 * Adds an item to the list of @c inAppIncludes.
 * @param inAppInclude The prefix of the framework name.
 */
- (void)addInAppInclude:(NSString *)inAppInclude;

@end

NS_ASSUME_NONNULL_END
