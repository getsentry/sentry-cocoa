#import "SentryDefines.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryThreadWrapper;
@class SentryFramesTracker;

NS_ASSUME_NONNULL_BEGIN

@interface SentryANRTrackerV2 : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
                          framesTracker:(SentryFramesTracker *)framesTracker;

- (void)addListener:(id<SentryANRTrackerV2Delegate>)listener;

- (void)removeListener:(id<SentryANRTrackerV2Delegate>)listener;

// Function used for tests
- (void)clear;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
