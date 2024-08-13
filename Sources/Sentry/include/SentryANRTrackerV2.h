#import "SentryDefines.h"

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryThreadWrapper;
@class SentryFramesTracker;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryANRType) {
    kSentryANRTypeFullyBlocking = 1,
    kSentryANRTypeNonFullyBlocking,
};

@protocol SentryANRTrackerV2Delegate;

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

/**
 * The ``SentryANRTrackerV2`` calls the methods from background threads.
 */
@protocol SentryANRTrackerV2Delegate <NSObject>

- (void)anrDetected:(SentryANRType)type;

- (void)anrStopped;

@end

NS_ASSUME_NONNULL_END
