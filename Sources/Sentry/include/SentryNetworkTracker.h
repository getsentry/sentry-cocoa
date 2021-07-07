#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"http.client";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;

- (void)enable;

- (void)disable;

@end

NS_ASSUME_NONNULL_END
