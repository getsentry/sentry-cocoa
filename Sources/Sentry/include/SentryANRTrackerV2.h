#import "SentryDefines.h"

@class SentryOptions, SentryCrashWrapper, SentryDispatchQueueWrapper, SentryThreadWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryANRTrackerV2Delegate;

@interface SentryANRTrackerV2 : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper;

- (void)addListener:(id<SentryANRTrackerV2Delegate>)listener;

- (void)removeListener:(id<SentryANRTrackerV2Delegate>)listener;

// Function used for tests
- (void)clear;

@end

@protocol SentryANRTrackerV2Delegate <NSObject>

- (void)anrDetected;

- (void)anrStopped;

@end

NS_ASSUME_NONNULL_END
