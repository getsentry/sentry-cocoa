#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"http.client";
static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;
- (void)urlSessionTask:(NSURLSessionTask *)sessionTask setState:(NSURLSessionTaskState)newState;

- (nullable NSDictionary *)addTraceHeader:(nullable NSDictionary *)headers;

- (void)enable;

- (void)disable;

@property (nonatomic, assign, readonly) BOOL isEnabled;

@end

NS_ASSUME_NONNULL_END
