#import <Foundation/Foundation.h>
#import "SOCSentryLevel.h"
#import "SOCSentryLastRunStatus.h"

@class SOCSentryDsn;
@class SOCSentryEvent;
@class SOCSentrySpan;
@class SOCSentryBreadcrumb;
@class SOCSentrySamplingContext;
@class SOCSentryScope;

NS_ASSUME_NONNULL_BEGIN

/// Configuration options for the Sentry SDK.
@interface SOCSentryOptions : NSObject

- (instancetype)init;

@property (nonatomic, copy, nullable) NSString *dsn;
@property (nonatomic) BOOL debug;
@property (nonatomic) SOCSentryLevel diagnosticLevel;
@property (nonatomic, copy, nullable) NSString *releaseName;
@property (nonatomic, copy, nullable) NSString *dist;
@property (nonatomic, copy) NSString *environment;
@property (nonatomic) BOOL enabled;
@property (nonatomic) NSTimeInterval shutdownTimeInterval;
@property (nonatomic) BOOL enableCrashHandler;
@property (nonatomic) BOOL enableSigtermReporting;
@property (nonatomic) NSUInteger maxBreadcrumbs;
@property (nonatomic) BOOL enableNetworkBreadcrumbs;
@property (nonatomic) BOOL enableAutoBreadcrumbTracking;
@property (nonatomic) NSUInteger maxCacheItems;
@property (nonatomic) NSUInteger maxAttachmentSize;
@property (nonatomic, copy) NSString *cacheDirectoryPath;
@property (nonatomic) BOOL sendClientReports;
@property (nonatomic) BOOL enableLogs;
@property (nonatomic) BOOL enableMetrics;
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic, strong, nullable) NSNumber *tracesSampleRate;
@property (nonatomic, readonly) BOOL isTracingEnabled;
@property (nonatomic) BOOL enableAutoSessionTracking;
@property (nonatomic) NSUInteger sessionTrackingIntervalMillis;
@property (nonatomic) BOOL enableWatchdogTerminationTracking;
@property (nonatomic) BOOL attachStacktrace;
@property (nonatomic) BOOL attachAllThreads;
@property (nonatomic) BOOL sendDefaultPii;
@property (nonatomic) BOOL enableAutoPerformanceTracing;
@property (nonatomic) BOOL enablePersistingTracesWhenCrashing;
@property (nonatomic) BOOL enableNetworkTracking;
@property (nonatomic) BOOL enableFileIOTracing;
@property (nonatomic) BOOL enableDataSwizzling;
@property (nonatomic) BOOL enableFileManagerSwizzling;
@property (nonatomic) BOOL enableCoreDataTracing;
@property (nonatomic) BOOL enableGraphQLOperationTracking;
@property (nonatomic) BOOL enableTimeToFullDisplayTracing;
@property (nonatomic) BOOL swiftAsyncStacktraces;
@property (nonatomic) BOOL enableUIViewControllerTracing;
@property (nonatomic) BOOL attachScreenshot;
@property (nonatomic) BOOL attachViewHierarchy;
@property (nonatomic) BOOL reportAccessibilityIdentifier;
@property (nonatomic) BOOL enableUserInteractionTracing;
@property (nonatomic) NSTimeInterval idleTimeout;
@property (nonatomic) BOOL enablePreWarmedAppStartTracing;
@property (nonatomic) BOOL enableReportNonFullyBlockingAppHangs;
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppIncludes;

- (void)addInAppInclude:(NSString *)inAppInclude;

@property (nonatomic, strong, nullable) id<NSURLSessionDelegate> urlSessionDelegate;
@property (nonatomic, strong, nullable) NSURLSession *urlSession;
@property (nonatomic) BOOL enablePropagateTraceparent;
@property (nonatomic, copy) NSArray *tracePropagationTargets;
@property (nonatomic) BOOL enableCaptureFailedRequests;
@property (nonatomic, copy) NSArray *failedRequestTargets;
@property (nonatomic) BOOL enableSwizzling;
@property (nonatomic, copy) NSSet<NSString *> *swizzleClassNameExcludes;
@property (nonatomic) BOOL enableAppHangTracking;
@property (nonatomic) NSTimeInterval appHangTimeoutInterval;
@property (nonatomic) BOOL enableMetricKit;
@property (nonatomic) BOOL enableMetricKitRawPayload;
@property (nonatomic) BOOL enableSpotlight;
@property (nonatomic, copy) NSString *spotlightUrl;
@property (nonatomic) BOOL strictTraceContinuation;
@property (nonatomic, copy, nullable) NSString *orgId;
@property (nonatomic, strong, nullable) SOCSentryDsn *parsedDsn;

/// Block called for every captured event before it's sent. Return nil to drop.
@property (nonatomic, copy, nullable) SOCSentryEvent *_Nullable (^beforeSend)(SOCSentryEvent *event);

/// Block called for every span before it's sent. Return nil to drop.
@property (nonatomic, copy, nullable) SOCSentrySpan *_Nullable (^beforeSendSpan)(SOCSentrySpan *span);

/// Block called for every breadcrumb before it's added. Return nil to drop.
@property (nonatomic, copy, nullable) SOCSentryBreadcrumb *_Nullable (^beforeBreadcrumb)(SOCSentryBreadcrumb *breadcrumb);

/// Called once after init with the crash event captured during the previous run.
@property (nonatomic, copy, nullable) void (^onCrashedLastRun)(SOCSentryEvent *event)
    __attribute__((deprecated("Use onLastRunStatusDetermined instead, which is called regardless of whether the app crashed.")));

/// Called once after the crash status of the last program execution is known.
@property (nonatomic, copy, nullable)
    void (^onLastRunStatusDetermined)(SOCSentryLastRunStatus status, SOCSentryEvent *_Nullable event);

/// Dynamic sampler for transactions.
@property (nonatomic, copy, nullable)
    NSNumber *_Nullable (^tracesSampler)(SOCSentrySamplingContext *context);

/// Decide whether to capture a screenshot for a given event.
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureScreenshot)(SOCSentryEvent *event);

/// Decide whether to capture a view hierarchy for a given event.
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureViewHierarchy)(SOCSentryEvent *event);

/// Block used to construct the initial scope. Defaults to identity.
@property (nonatomic, copy) SOCSentryScope *(^initialScope)(SOCSentryScope *scope);

@end

NS_ASSUME_NONNULL_END
