// swiftlint:disable file_length
#import "SentryObjCDefines.h"
#import "SentryObjCLastRunStatus.h"
#import "SentryObjCLevel.h"
#import <Foundation/Foundation.h>

@class SentryObjCBreadcrumb;
@class SentryObjCEvent;
@class SentryObjCExperimentalOptions;
@class SentryObjCHttpStatusCodeRange;
@class SentryObjCReplayOptions;
@class SentryObjCSamplingContext;
@class SentryObjCScope;
@class SentryObjCSpan;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCOptions : NSObject

@property (nonatomic, copy, nullable) NSString *dsn;
@property (nonatomic) BOOL debug;
@property (nonatomic) SentryObjCLevel diagnosticLevel;
@property (nonatomic, copy, nullable) NSString *releaseName;
@property (nonatomic, copy, nullable) NSString *dist;
@property (nonatomic, copy) NSString *environment;
@property (nonatomic) BOOL enabled;
@property (nonatomic) NSTimeInterval shutdownTimeInterval;
@property (nonatomic) BOOL enableCrashHandler;
@property (nonatomic) NSUInteger maxBreadcrumbs;
@property (nonatomic) BOOL enableNetworkBreadcrumbs;
@property (nonatomic) NSUInteger maxCacheItems;
@property (nonatomic, copy, nullable) SentryObjCEvent *_Nullable (^beforeSend)(SentryObjCEvent *);
@property (nonatomic, copy, nullable) SentryObjCSpan *_Nullable (^beforeSendSpan)(SentryObjCSpan *);
@property (nonatomic) BOOL enableLogs;
@property (nonatomic, copy, nullable) SentryObjCBreadcrumb *_Nullable (^beforeBreadcrumb)
    (SentryObjCBreadcrumb *);
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureScreenshot)(SentryObjCEvent *);
@property (nonatomic, copy, nullable) BOOL (^beforeCaptureViewHierarchy)(SentryObjCEvent *);
@property (nonatomic, copy, nullable) void (^onCrashedLastRun)(SentryObjCEvent *)
    __attribute__((deprecated("Use onLastRunStatusDetermined instead.")));
@property (nonatomic, copy, nullable) void (^onLastRunStatusDetermined)
    (SentryObjCLastRunStatus, SentryObjCEvent *_Nullable);
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic) BOOL enableAutoSessionTracking;
@property (nonatomic) BOOL enableGraphQLOperationTracking;
@property (nonatomic) BOOL enableWatchdogTerminationTracking;
@property (nonatomic) NSUInteger sessionTrackingIntervalMillis;
@property (nonatomic) BOOL attachStacktrace;
@property (nonatomic) BOOL attachAllThreads;
@property (nonatomic) NSUInteger maxAttachmentSize;
@property (nonatomic) BOOL sendDefaultPii;
@property (nonatomic) BOOL enableAutoPerformanceTracing;
@property (nonatomic) BOOL enablePersistingTracesWhenCrashing;
@property (nonatomic, copy) SentryObjCScope * (^initialScope)(SentryObjCScope *);
@property (nonatomic) BOOL enableNetworkTracking;
@property (nonatomic) BOOL enableFileIOTracing;
@property (nonatomic) BOOL enableDataSwizzling;
@property (nonatomic) BOOL enableFileManagerSwizzling;
@property (nonatomic, strong, nullable) NSNumber *tracesSampleRate;
@property (nonatomic, copy, nullable) NSNumber *_Nullable (^tracesSampler)
    (SentryObjCSamplingContext *);
@property (nonatomic, readonly) BOOL isTracingEnabled;
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppIncludes;
@property (nonatomic, weak, nullable) id<NSURLSessionDelegate> urlSessionDelegate;
@property (nonatomic, strong, nullable) NSURLSession *urlSession;
@property (nonatomic) BOOL enableSwizzling;
@property (nonatomic, copy) NSSet<NSString *> *swizzleClassNameExcludes;
@property (nonatomic) BOOL enableCoreDataTracing;
@property (nonatomic) BOOL sendClientReports;
@property (nonatomic) BOOL enableAppHangTracking;
@property (nonatomic) NSTimeInterval appHangTimeoutInterval;
@property (nonatomic) BOOL enableAutoBreadcrumbTracking;
@property (nonatomic) BOOL enablePropagateTraceparent;
@property (nonatomic, copy) NSArray *tracePropagationTargets;
@property (nonatomic) BOOL enableCaptureFailedRequests;
@property (nonatomic, copy) NSArray<SentryObjCHttpStatusCodeRange *> *failedRequestStatusCodes;
@property (nonatomic, copy) NSArray *failedRequestTargets;
@property (nonatomic) BOOL enableTimeToFullDisplayTracing;
@property (nonatomic) BOOL swiftAsyncStacktraces;
@property (nonatomic, copy) NSString *cacheDirectoryPath;
@property (nonatomic) BOOL enableSpotlight;
@property (nonatomic, copy) NSString *spotlightUrl;
@property (nonatomic) BOOL strictTraceContinuation;
@property (nonatomic, copy, nullable) NSString *orgId;
@property (nonatomic, strong) SentryObjCExperimentalOptions *experimental;
@property (nonatomic) BOOL enableMetrics;

- (instancetype)init;
- (void)addInAppInclude:(NSString *)inAppInclude;

@end

NS_ASSUME_NONNULL_END
