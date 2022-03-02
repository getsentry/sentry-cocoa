#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

@class SentryOptions, SentryCrashAdapter, SentryDispatchQueueWrapper, SentryThreadWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryANRTrackerDelegate;

@interface SentryANRTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithDelegate:(id<SentryANRTrackerDelegate>)delegate
           timeoutIntervalMillis:(NSUInteger)timeoutIntervalMillis
             currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                    crashAdapter:(SentryCrashAdapter *)crashAdapter
            dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                   threadWrapper:(SentryThreadWrapper *)threadWrapper;

- (void)start;

- (void)stop;

@end

@protocol SentryANRTrackerDelegate <NSObject>

- (void)anrDetected;

- (void)anrStopped;

@end

NS_ASSUME_NONNULL_END
