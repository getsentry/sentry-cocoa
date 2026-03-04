#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCLevel.h"

@class SentryReplayOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * Configuration options for the Sentry SDK.
 *
 * @see SentrySDK
 */
@interface SentryOptions : NSObject

@property (nonatomic, copy, nullable) NSString *dsn;
@property (nonatomic, strong, nullable) id parsedDsn;
@property (nonatomic, assign) BOOL debug;
@property (nonatomic, assign) SentryLevel diagnosticLevel;
@property (nonatomic, copy, nullable) NSString *releaseName;
@property (nonatomic, copy, nullable) NSString *dist;
@property (nonatomic, copy) NSString *environment;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval shutdownTimeInterval;
@property (nonatomic, assign) BOOL enableCrashHandler;
@property (nonatomic, assign) NSUInteger maxBreadcrumbs;
@property (nonatomic, assign) BOOL enableNetworkBreadcrumbs;
@property (nonatomic, assign) NSUInteger maxCacheItems;
@property (nonatomic, copy, nullable) SentryBeforeSendEventCallback beforeSend;
@property (nonatomic, copy, nullable) SentryBeforeSendSpanCallback beforeSendSpan;
@property (nonatomic, assign) BOOL enableLogs;
@property (nonatomic, copy, nullable) SentryBeforeBreadcrumbCallback beforeBreadcrumb;
@property (nonatomic, copy, nullable) SentryBeforeCaptureScreenshotCallback beforeCaptureScreenshot;
@property (nonatomic, copy, nullable)
    SentryBeforeCaptureScreenshotCallback beforeCaptureViewHierarchy;
@property (nonatomic, copy, nullable) SentryOnCrashedLastRunCallback onCrashedLastRun;
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic, assign) BOOL enableAutoSessionTracking;
@property (nonatomic, assign) BOOL enableGraphQLOperationTracking;
@property (nonatomic, assign) BOOL enableWatchdogTerminationTracking;
@property (nonatomic, assign) NSUInteger sessionTrackingIntervalMillis;
@property (nonatomic, assign) BOOL attachStacktrace;
@property (nonatomic, assign) NSUInteger maxAttachmentSize;
@property (nonatomic, assign) BOOL sendDefaultPii;
@property (nonatomic, assign) BOOL enableAutoPerformanceTracing;
@property (nonatomic, assign) BOOL enablePersistingTracesWhenCrashing;
@property (nonatomic, copy, nullable) id initialScope;

#if SENTRY_OBJC_UIKIT_AVAILABLE
@property (nonatomic, assign) BOOL enableUIViewControllerTracing;
@property (nonatomic, assign) BOOL attachScreenshot;
@property (nonatomic, strong) id screenshot;
@property (nonatomic, assign) BOOL attachViewHierarchy;
@property (nonatomic, assign) BOOL reportAccessibilityIdentifier;
@property (nonatomic, assign) BOOL enableUserInteractionTracing;
@property (nonatomic, assign) NSTimeInterval idleTimeout;
@property (nonatomic, assign) BOOL enablePreWarmedAppStartTracing;
@property (nonatomic, assign) BOOL enableReportNonFullyBlockingAppHangs;
@property (nonatomic, strong) SentryReplayOptions *sessionReplay;
#endif

@property (nonatomic, assign) BOOL enableNetworkTracking;
@property (nonatomic, assign) BOOL enableFileIOTracing;
@property (nonatomic, assign) BOOL enableDataSwizzling;
@property (nonatomic, assign) BOOL enableFileManagerSwizzling;
@property (nonatomic, strong, nullable) NSNumber *tracesSampleRate;
@property (nonatomic, copy, nullable) SentryTracesSamplerCallback tracesSampler;
@property (nonatomic, readonly) BOOL isTracingEnabled;
@property (nonatomic, copy) NSArray<NSString *> *inAppIncludes;
@property (nonatomic, weak, nullable) id urlSessionDelegate;
@property (nonatomic, strong, nullable) NSURLSession *urlSession;
@property (nonatomic, assign) BOOL enableSwizzling;
@property (nonatomic, copy) NSSet<NSString *> *swizzleClassNameExcludes;
@property (nonatomic, assign) BOOL enableCoreDataTracing;
@property (nonatomic, assign) BOOL sendClientReports;
@property (nonatomic, assign) BOOL enableAppHangTracking;
@property (nonatomic, assign) NSTimeInterval appHangTimeoutInterval;
@property (nonatomic, assign) BOOL enableAutoBreadcrumbTracking;
@property (nonatomic, assign) BOOL enablePropagateTraceparent;
@property (nonatomic, copy) NSArray *tracePropagationTargets;
@property (nonatomic, assign) BOOL enableCaptureFailedRequests;
@property (nonatomic, copy) NSArray *failedRequestStatusCodes;
@property (nonatomic, copy) NSArray *failedRequestTargets;
@property (nonatomic, assign) BOOL enableTimeToFullDisplayTracing;
@property (nonatomic, assign) BOOL swiftAsyncStacktraces;
@property (nonatomic, copy) NSString *cacheDirectoryPath;
@property (nonatomic, assign) BOOL enableSpotlight;
@property (nonatomic, copy) NSString *spotlightUrl;
@property (nonatomic, strong) id experimental;

- (void)addInAppInclude:(NSString *)inAppInclude;

@end

NS_ASSUME_NONNULL_END
