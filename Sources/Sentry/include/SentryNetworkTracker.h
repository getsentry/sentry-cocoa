#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;
@protocol SentryAutoSpanStarter;

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"http.client";
static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN";
static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB
    = @"SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;
- (void)urlSessionTask:(NSURLSessionTask *)sessionTask setState:(NSURLSessionTaskState)newState;
- (void)enableNetworkTracking;
- (void)enableNetworkBreadcrumbs;
- (void)enableCaptureFailedRequests;
- (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets;
- (void)disable;
- (void)setAutoSpanStarter:(id<SentryAutoSpanStarter>)autoSpanStarter;

@property (nonatomic, readonly) BOOL isNetworkTrackingEnabled;
@property (nonatomic, readonly) BOOL isNetworkBreadcrumbEnabled;
@property (nonatomic, readonly) BOOL isCaptureFailedRequestsEnabled;

@end

NS_ASSUME_NONNULL_END
