#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

@class SentryOptions, SentryCrashWrapper, SentryDispatchQueueWrapper, SentryThreadWrapper;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * As we only use the ANR tracking integration for detecting falsely reported OOMs we can use a more
 * defensive value, because we are not reporting any ANRs.
 */
static NSUInteger const SENTRY_ANR_TRACKER_TIMEOUT_MILLIS = 2000;

@protocol SentryANRTrackerDelegate;

/**
 * This class detects ANRs with a dedicated watchdog thread. The thread schedules a simple block to
 * run on the main thread, sleeps for the configured timeout interval, and checks if the main thread
 * executed this block.
 *
 * @discussion We decided against using a CFRunLoopObserver or the CADisplayLink, which the
 * SentryFramesTracker already uses, because they come with two disadvantages. First, the solution
 * is expensive. Quick benchmarks showed that hooking into the main thread's run loop and checking
 * for every event to process if the main thread executes it in time added around 0,5 % of CPU
 * overhead. Furthermore, if the main thread runs all scheduled events in time, it doesn't mean that
 * there is no ANR ongoing. It could be that the run loop of the main thread is busy for 20 seconds,
 * and it executes all events in time. Instead, what matters is how long the main thread needs to
 * execute a newly added event to the run loop.
 */
@interface SentryANRTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                    crashWrapper:(SentryCrashWrapper *)crashWrapper
            dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                   threadWrapper:(SentryThreadWrapper *)threadWrapper;

@property (nonatomic, assign) NSTimeInterval timeoutInterval;

- (void)addListener:(id<SentryANRTrackerDelegate>)listener;

- (void)removeListener:(id<SentryANRTrackerDelegate>)listener;

- (void)clear;

@end

@protocol SentryANRTrackerDelegate <NSObject>

- (void)anrDetected;

- (void)anrStopped;

@end

#endif

NS_ASSUME_NONNULL_END
