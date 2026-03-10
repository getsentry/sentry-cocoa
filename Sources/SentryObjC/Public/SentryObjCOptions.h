#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCLevel.h"

@class SentryReplayOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * Configuration options for the Sentry SDK.
 *
 * Configure all SDK features and behavior through this object before
 * passing it to @c +[SentrySDK startWithOptions:].
 *
 * @see SentrySDK
 */
@interface SentryOptions : NSObject

/**
 * The DSN (Data Source Name) for your Sentry project.
 *
 * This uniquely identifies your project and directs events to the correct endpoint.
 */
@property (nonatomic, copy, nullable) NSString *dsn;

/**
 * Parsed representation of the DSN.
 *
 * @warning This is maintained automatically and should not be set directly.
 */
@property (nonatomic, strong, nullable) id parsedDsn;

/**
 * Whether to enable debug mode.
 *
 * When @c YES, the SDK will output detailed logs. Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL debug;

/**
 * The minimum level for diagnostic messages to be logged.
 *
 * Only messages at or above this level will be logged.
 */
@property (nonatomic, assign) SentryLevel diagnosticLevel;

/**
 * The release version of your application.
 *
 * Format: @c \<package-name\>@\<version\>+\<build\> (e.g., "my.app@1.0.0+123").
 * If not set, the SDK will attempt to detect it automatically.
 */
@property (nonatomic, copy, nullable) NSString *releaseName;

/**
 * The distribution identifier for this release.
 *
 * Used to distinguish different distributions of the same release (e.g., "enterprise", "appstore").
 */
@property (nonatomic, copy, nullable) NSString *dist;

/**
 * The environment name (e.g., "production", "staging", "development").
 *
 * Defaults to "production".
 */
@property (nonatomic, copy) NSString *environment;

/**
 * Whether the SDK is enabled.
 *
 * When @c NO, the SDK will not send any events. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Maximum time to wait for pending events to be sent during shutdown.
 *
 * Specified in seconds. Defaults to 2 seconds.
 */
@property (nonatomic, assign) NSTimeInterval shutdownTimeInterval;

/**
 * Whether to install the crash handler.
 *
 * When @c YES, the SDK will capture crashes. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableCrashHandler;

/**
 * Maximum number of breadcrumbs to keep.
 *
 * When the limit is exceeded, older breadcrumbs are removed. Defaults to 100.
 */
@property (nonatomic, assign) NSUInteger maxBreadcrumbs;

/**
 * Whether to automatically capture network request breadcrumbs.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableNetworkBreadcrumbs;

/**
 * Maximum number of events to cache on disk.
 *
 * When the limit is exceeded, the oldest events are removed. Defaults to 30.
 */
@property (nonatomic, assign) NSUInteger maxCacheItems;

/**
 * Callback invoked before an event is sent.
 *
 * Use this to modify or filter events. Return @c nil to prevent sending.
 */
@property (nonatomic, copy, nullable) SentryBeforeSendEventCallback beforeSend;

/**
 * Callback invoked before a span is sent.
 *
 * Use this to modify or filter spans. Return @c nil to prevent sending.
 */
@property (nonatomic, copy, nullable) SentryBeforeSendSpanCallback beforeSendSpan;

/**
 * Whether to enable automatic log capture.
 *
 * When @c YES, logs will be captured and sent to Sentry. Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL enableLogs;

/**
 * Callback invoked before a breadcrumb is added.
 *
 * Use this to modify or filter breadcrumbs. Return @c nil to prevent adding.
 */
@property (nonatomic, copy, nullable) SentryBeforeBreadcrumbCallback beforeBreadcrumb;

/**
 * Callback invoked before a screenshot is captured.
 *
 * Return @c nil to prevent capturing the screenshot.
 */
@property (nonatomic, copy, nullable) SentryBeforeCaptureScreenshotCallback beforeCaptureScreenshot;

/**
 * Callback invoked before the view hierarchy is captured.
 *
 * Return @c nil to prevent capturing the view hierarchy.
 */
@property (nonatomic, copy, nullable)
    SentryBeforeCaptureScreenshotCallback beforeCaptureViewHierarchy;

/**
 * Callback invoked when the SDK determines the app crashed on the previous run.
 *
 * Use this to perform custom logic when a crash is detected.
 */
@property (nonatomic, copy, nullable) SentryOnCrashedLastRunCallback onCrashedLastRun;

/**
 * The sample rate for error events.
 *
 * A value between 0.0 (0%) and 1.0 (100%). Defaults to 1.0 (all events sent).
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * Whether to enable automatic session tracking.
 *
 * When @c YES, sessions are automatically started and stopped. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableAutoSessionTracking;

/**
 * Whether to enable automatic GraphQL operation tracking.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableGraphQLOperationTracking;

/**
 * Whether to track watchdog terminations.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableWatchdogTerminationTracking;

/**
 * Interval for session tracking in milliseconds.
 *
 * Sessions are sent to Sentry at this interval. Defaults to 30000 (30 seconds).
 */
@property (nonatomic, assign) NSUInteger sessionTrackingIntervalMillis;

/**
 * Whether to attach stack traces to captured messages.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL attachStacktrace;

/**
 * Maximum size for attachments in bytes.
 *
 * Attachments larger than this will not be sent. Defaults to 20 MB.
 */
@property (nonatomic, assign) NSUInteger maxAttachmentSize;

/**
 * Whether to send default personally identifiable information (PII).
 *
 * When @c YES, user IP addresses and usernames are sent. Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL sendDefaultPii;

/**
 * Whether to enable automatic performance tracing.
 *
 * Defaults to @c YES when @c tracesSampleRate or @c tracesSampler is set.
 */
@property (nonatomic, assign) BOOL enableAutoPerformanceTracing;

/**
 * Whether to persist traces when the application crashes.
 *
 * This allows traces to be sent with crash reports. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enablePersistingTracesWhenCrashing;

/**
 * Initial scope data to apply when the SDK starts.
 *
 * Set this to pre-populate the scope with tags, extras, or other data.
 */
@property (nonatomic, copy, nullable) id initialScope;

#if SENTRY_OBJC_UIKIT_AVAILABLE
/**
 * Whether to enable automatic view controller tracing.
 *
 * When @c YES, navigation between view controllers is automatically traced. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableUIViewControllerTracing;

/**
 * Whether to attach screenshots to error events.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL attachScreenshot;

/**
 * Configuration for screenshot attachment.
 *
 * @warning This is maintained automatically.
 */
@property (nonatomic, strong) id screenshot;

/**
 * Whether to attach the view hierarchy to error events.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL attachViewHierarchy;

/**
 * Whether to include accessibility identifiers in the view hierarchy.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL reportAccessibilityIdentifier;

/**
 * Whether to enable automatic user interaction tracing.
 *
 * When @c YES, user taps and swipes are automatically traced. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableUserInteractionTracing;

/**
 * The idle timeout for automatically finishing transactions.
 *
 * If no child spans are running for this duration, the transaction is automatically finished.
 * Specified in seconds. Defaults to 3 seconds.
 */
@property (nonatomic, assign) NSTimeInterval idleTimeout;

/**
 * Whether to trace app start for pre-warmed launches.
 *
 * Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL enablePreWarmedAppStartTracing;

/**
 * Whether to report app hangs that don't fully block the main thread.
 *
 * Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL enableReportNonFullyBlockingAppHangs;

/**
 * Configuration options for Session Replay.
 */
@property (nonatomic, strong) SentryReplayOptions *sessionReplay;
#endif

/**
 * Whether to enable automatic network request tracing.
 *
 * When @c YES, network requests are automatically traced. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableNetworkTracking;

/**
 * Whether to enable file I/O tracing.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableFileIOTracing;

/**
 * Whether to enable method swizzling for automatic instrumentation.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableDataSwizzling;

/**
 * Whether to swizzle @c NSFileManager methods for file I/O tracing.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableFileManagerSwizzling;

/**
 * The sample rate for performance traces.
 *
 * A value between 0.0 (0%) and 1.0 (100%). Defaults to @c nil (no tracing).
 */
@property (nonatomic, strong, nullable) NSNumber *tracesSampleRate;

/**
 * Callback for dynamic trace sampling decisions.
 *
 * If set, this callback is invoked for each transaction to determine
 * whether it should be sampled.
 */
@property (nonatomic, copy, nullable) SentryTracesSamplerCallback tracesSampler;

/**
 * Whether performance tracing is enabled.
 *
 * @c YES if @c tracesSampleRate or @c tracesSampler is set.
 */
@property (nonatomic, readonly) BOOL isTracingEnabled;

/**
 * List of module/package prefixes to consider as in-app code.
 *
 * Stack frames from these modules are marked as in-app.
 */
@property (nonatomic, copy) NSArray<NSString *> *inAppIncludes;

/**
 * Custom delegate for the SDK's @c NSURLSession.
 */
@property (nonatomic, weak, nullable) id urlSessionDelegate;

/**
 * Custom @c NSURLSession for network communication.
 *
 * If not set, the SDK creates its own session.
 */
@property (nonatomic, strong, nullable) NSURLSession *urlSession;

/**
 * Whether to enable method swizzling globally.
 *
 * When @c NO, automatic instrumentation is disabled. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableSwizzling;

/**
 * Set of class name prefixes to exclude from swizzling.
 *
 * Classes whose names start with these prefixes will not be swizzled.
 */
@property (nonatomic, copy) NSSet<NSString *> *swizzleClassNameExcludes;

/**
 * Whether to enable Core Data tracing.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableCoreDataTracing;

/**
 * Whether to send client reports about dropped events.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL sendClientReports;

/**
 * Whether to enable app hang tracking.
 *
 * When @c YES, the SDK detects when the main thread is blocked. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableAppHangTracking;

/**
 * Threshold for detecting app hangs.
 *
 * If the main thread is blocked for longer than this duration, it's reported
 * as an app hang. Specified in seconds. Defaults to 2 seconds.
 */
@property (nonatomic, assign) NSTimeInterval appHangTimeoutInterval;

/**
 * Whether to enable automatic breadcrumb tracking.
 *
 * When @c YES, various system events are automatically captured as breadcrumbs. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableAutoBreadcrumbTracking;

/**
 * Whether to propagate trace context in HTTP headers.
 *
 * When @c YES, @c sentry-trace and @c baggage headers are added to outgoing requests. Defaults to
 * @c YES.
 */
@property (nonatomic, assign) BOOL enablePropagateTraceparent;

/**
 * List of URL patterns for trace propagation.
 *
 * Only requests to URLs matching these patterns will have trace headers added.
 * If empty, all requests receive headers.
 */
@property (nonatomic, copy) NSArray *tracePropagationTargets;

/**
 * Whether to capture HTTP requests that result in error status codes.
 *
 * Defaults to @c YES when tracing is enabled.
 */
@property (nonatomic, assign) BOOL enableCaptureFailedRequests;

/**
 * List of HTTP status code ranges to consider as failed requests.
 *
 * Requests with these status codes are captured as error events.
 */
@property (nonatomic, copy) NSArray *failedRequestStatusCodes;

/**
 * List of URL patterns to capture when they result in failed requests.
 *
 * Only requests to URLs matching these patterns are captured.
 */
@property (nonatomic, copy) NSArray *failedRequestTargets;

/**
 * Whether to enable Time To Full Display tracking.
 *
 * Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL enableTimeToFullDisplayTracing;

/**
 * Whether to capture stack traces from Swift async functions.
 *
 * Defaults to @c YES on iOS 15+.
 */
@property (nonatomic, assign) BOOL swiftAsyncStacktraces;

/**
 * Custom directory path for caching events.
 *
 * If not set, the SDK uses the default cache directory.
 */
@property (nonatomic, copy) NSString *cacheDirectoryPath;

/**
 * Whether to enable Spotlight integration for local debugging.
 *
 * Defaults to @c NO.
 */
@property (nonatomic, assign) BOOL enableSpotlight;

/**
 * URL for the Spotlight server.
 *
 * Defaults to @c "http://localhost:8969/stream".
 */
@property (nonatomic, copy) NSString *spotlightUrl;

/**
 * Experimental features configuration.
 *
 * Access experimental SDK features through this property.
 */
@property (nonatomic, strong) id experimental;

/**
 * Adds a module/package prefix to the in-app includes list.
 *
 * @param inAppInclude The module prefix to add.
 */
- (void)addInAppInclude:(NSString *)inAppInclude;

@end

NS_ASSUME_NONNULL_END
