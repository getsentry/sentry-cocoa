#import "SentryANRTrackerV2.h"

#if SENTRY_HAS_UIKIT

#    import "SentryANRStoppedResultInternal.h"
#    import "SentryANRTrackerInternalDelegate.h"
#    import "SentryLogC.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"
#    import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryANRTrackerState) {
    kSentryANRTrackerNotRunning = 1,
    kSentryANRTrackerRunning,
    kSentryANRTrackerStarting,
    kSentryANRTrackerStopping
};

@interface SentryANRTrackerV2 ()

@property (nonatomic, strong) id<SentryApplicationStateProvider> applicationStateProvider;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSHashTable<id<SentryANRTrackerInternalDelegate>> *listeners;
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end

@implementation SentryANRTrackerV2 {
    NSObject *threadLock;
    SentryANRTrackerState state;
}

/**
 * Returns the frames delay to trust for hang classification, and via @c trustedFramesCount the
 * matching frames count when passed non NULL.
 *
 * When the main thread drains its queue, the run loop turns, and an active display link fires
 * within roughly one frame duration afterwards. So when the main thread is responsive, an ongoing
 * frame gap larger than the @c sleepInterval means the app isn't rendering although the main
 * thread isn't blocked, and the ongoing frame's delay must be ignored. Recorded delayed frames
 * stay trusted because they actually rendered. The ongoing frame always contributes one frame to
 * @c framesContributingToDelayCount (see @c getFramesDelayObjC), so ignoring its delay also
 * removes it from the trusted frames count.
 */
static CFTimeInterval
getTrustedFramesDelayDuration(SentryFramesDelayResultSPI *framesDelay,
    BOOL isMainThreadUnresponsive, NSTimeInterval sleepInterval,
    NSUInteger *_Nullable trustedFramesCount)
{
    CFTimeInterval delayDuration = framesDelay.delayDuration;
    NSUInteger framesCount = framesDelay.framesContributingToDelayCount;

    if (!isMainThreadUnresponsive && framesDelay.ongoingFrameDelayDuration > sleepInterval) {
        delayDuration -= framesDelay.ongoingFrameDelayDuration;
        framesCount -= 1;
    }

    if (trustedFramesCount != NULL) {
        *trustedFramesCount = framesCount;
    }
    return delayDuration;
}

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
{
    return [self
         initWithTimeoutInterval:timeoutInterval
        applicationStateProvider:SentryDependencyContainer.sharedInstance.applicationStateProvider
            dispatchQueueWrapper:SentryDependencyContainer.sharedInstance.dispatchQueueWrapper
                   threadWrapper:SentryDependencyContainer.sharedInstance.threadWrapper
                   framesTracker:SentryDependencyContainer.sharedInstance.framesTracker];
}

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
               applicationStateProvider:(id<SentryApplicationStateProvider>)applicationStateProvider
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
                          framesTracker:(SentryFramesTracker *)framesTracker
{
    if (self = [super init]) {
        self.timeoutInterval = timeoutInterval;
        self.applicationStateProvider = applicationStateProvider;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.threadWrapper = threadWrapper;
        self.framesTracker = framesTracker;
        self.listeners = [NSHashTable weakObjectsHashTable];
        threadLock = [[NSObject alloc] init];
        state = kSentryANRTrackerNotRunning;
    }
    return self;
}

- (void)detectANRs
{
    NSUUID *threadID = [NSUUID UUID];

    @synchronized(threadLock) {
        [self.threadWrapper threadStarted:threadID];

        if (state != kSentryANRTrackerStarting) {
            [self.threadWrapper threadFinished:threadID];
            return;
        }

        NSThread.currentThread.name = @"io.sentry.app-hang-tracker";
        state = kSentryANRTrackerRunning;
    }

    id<SentryCurrentDateProvider> dateProvider
        = SentryDependencyContainer.sharedInstance.dateProvider;

    BOOL reported = NO;

    // Ticks since the main thread last drained the main queue. When the ticks reach the
    // reportThreshold the main thread is treated as unresponsive; see the heartbeat block below.
    __block atomic_int ticksSinceLastMainQueueDrain = 0;

    NSInteger reportThreshold = 5;
    NSTimeInterval sleepInterval = self.timeoutInterval / reportThreshold;
    uint64_t sleepIntervalInNanos = timeIntervalToNanoseconds(sleepInterval);
    uint64_t timeoutIntervalInNanos = timeIntervalToNanoseconds(self.timeoutInterval);

    uint64_t appHangStoppedInterval = timeIntervalToNanoseconds(sleepInterval * 2);
    CFTimeInterval appHangStoppedFrameDelayThreshold
        = nanosecondsToTimeInterval(appHangStoppedInterval) * 0.2;

    uint64_t lastAppHangStoppedSystemTime = dateProvider.systemTime - timeoutIntervalInNanos;
    uint64_t lastAppHangStartedSystemTime = 0;

    // Track time to exclude from the hang duration calculation. While the app is in the
    // background, the frames tracker can't provide frame delay data, e.g. because it's paused, or
    // the OS suspends the app, the app can't be hanging, but the system time keeps ticking.
    BOOL isExcludingTime = NO;
    uint64_t excludedTimeStartSystemTime = 0;
    uint64_t accumulatedExcludedTime = 0;

    // Canceling the thread can take up to sleepInterval.
    while (YES) {
        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        NSDate *sleepDeadline = [[dateProvider date] dateByAddingTimeInterval:self.timeoutInterval];

        // Frame delay data alone can't distinguish a blocked main thread from an app that
        // legitimately stopped rendering while staying active, e.g. a CarPlay scene keeping the
        // app alive while the phone is locked, or the proximity sensor blanking the screen; see
        // https://github.com/getsentry/sentry-cocoa/issues/8317. This heartbeat provides the
        // missing signal: when the main thread drains its queue, it isn't blocked.
        atomic_fetch_add_explicit(&ticksSinceLastMainQueueDrain, 1, memory_order_relaxed);
        [self.dispatchQueueWrapper dispatchAsyncOnMainQueueIfNotMainThread:^{
            atomic_store_explicit(&ticksSinceLastMainQueueDrain, 0, memory_order_relaxed);
        }];

        [self.threadWrapper sleepForTimeInterval:sleepInterval];

        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        BOOL isInForeground = [self.applicationStateProvider isApplicationInForeground];

        if (!isInForeground) {
            SENTRY_LOG_DEBUG(@"Ignoring potential app hangs because the app is in the background");

            // Start excluding time from the hang duration. Background time is one of three
            // exclusion causes; see the declaration of isExcludingTime.
            if (reported && !isExcludingTime) {
                isExcludingTime = YES;
                excludedTimeStartSystemTime = dateProvider.systemTime;
            }

            continue;
        }

        // The sleepDeadline should be roughly executed after the timeoutInterval even if there is
        // an AppHang. If the app gets suspended this thread could sleep and wake up again. To avoid
        // false positives, we don't report AppHangs if the delta is too big.
        NSTimeInterval deltaFromNowToSleepDeadline =
            [[dateProvider date] timeIntervalSinceDate:sleepDeadline];

        if (deltaFromNowToSleepDeadline >= self.timeoutInterval) {
            SENTRY_LOG_DEBUG(@"Ignoring App Hang because the delta is too big: %f.",
                deltaFromNowToSleepDeadline);

            // The thread slept way longer than expected, e.g. because the OS suspended the app.
            // Exclude the extra sleep time from the hang duration. When already excluding time,
            // the ongoing excluded time span covers the extra sleep time.
            if (reported && !isExcludingTime) {
                accumulatedExcludedTime += timeIntervalToNanoseconds(
                    deltaFromNowToSleepDeadline + self.timeoutInterval - sleepInterval);
            }
            continue;
        }

        uint64_t nowSystemTime = dateProvider.systemTime;

        int mainQueueDrainTicks
            = atomic_load_explicit(&ticksSinceLastMainQueueDrain, memory_order_relaxed);
        BOOL isMainThreadUnresponsive = mainQueueDrainTicks >= reportThreshold;

        if (reported) {

            uint64_t framesDelayStartSystemTime = nowSystemTime - appHangStoppedInterval;

            SentryFramesDelayResultSPI *framesDelay =
                [self.framesTracker getFramesDelaySPI:framesDelayStartSystemTime
                                   endSystemTimestamp:nowSystemTime];

            if (framesDelay.delayDuration == -1) {
                // Without frame delay data, e.g. because the frames tracker is paused after the
                // app resigned active, the app can't be hanging. Exclude that time from the hang
                // duration.
                if (!isExcludingTime) {
                    isExcludingTime = YES;
                    excludedTimeStartSystemTime = nowSystemTime;
                }
                continue;
            }

            if (isExcludingTime) {
                accumulatedExcludedTime += nowSystemTime - excludedTimeStartSystemTime;
                isExcludingTime = NO;
            }

            CFTimeInterval framesDelayDuration = getTrustedFramesDelayDuration(
                framesDelay, isMainThreadUnresponsive, sleepInterval, NULL);

            BOOL appHangStopped = framesDelayDuration < appHangStoppedFrameDelayThreshold;

            if (appHangStopped) {
                SENTRY_LOG_DEBUG(@"App hang stopped.");

                // As we check every sleepInterval if the app is hanging, the app could already be
                // hanging for almost the sleepInterval until we detect it and it could already
                // stopped hanging almost a sleepInterval until we again detect it's not.
                //
                // Subtract any time during which the app couldn't have been hanging, such as
                // time in background, without frame delay data, or while the OS suspended the
                // app. The system time continues to tick during that time, but we don't want to
                // include it in the reported duration.
                uint64_t elapsedSystemTime = nowSystemTime - lastAppHangStartedSystemTime;
                uint64_t observedElapsedTime = elapsedSystemTime > accumulatedExcludedTime
                    ? elapsedSystemTime - accumulatedExcludedTime
                    : 0;
                uint64_t appHangDurationNanos = timeoutIntervalInNanos + observedElapsedTime;

                NSTimeInterval appHangDurationMinimum
                    = nanosecondsToTimeInterval(appHangDurationNanos - sleepIntervalInNanos);
                NSTimeInterval appHangDurationMaximum
                    = nanosecondsToTimeInterval(appHangDurationNanos + sleepIntervalInNanos);

                lastAppHangStoppedSystemTime = nowSystemTime;
                reported = NO;
                isExcludingTime = NO;
                accumulatedExcludedTime = 0;

                // The App Hang stopped, don't block the App Hangs thread or the main thread with
                // calling ANRStopped listeners.
                [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
                    [self ANRStopped:appHangDurationMinimum to:appHangDurationMaximum];
                }];
            }

            continue;
        }

        uint64_t lastAppHangLongEnoughInPastThreshold
            = lastAppHangStoppedSystemTime + timeoutIntervalInNanos;

        if (dateProvider.systemTime < lastAppHangLongEnoughInPastThreshold) {
            SENTRY_LOG_DEBUG(@"Ignoring app hang cause one happened recently.");
            continue;
        }

        uint64_t frameDelayStartSystemTime = nowSystemTime - timeoutIntervalInNanos;

        SentryFramesDelayResultSPI *framesDelayForTimeInterval =
            [self.framesTracker getFramesDelaySPI:frameDelayStartSystemTime
                               endSystemTimestamp:nowSystemTime];

        if (framesDelayForTimeInterval.delayDuration == -1) {
            continue;
        }

        NSUInteger framesContributingToDelayCount;
        CFTimeInterval delayDuration = getTrustedFramesDelayDuration(framesDelayForTimeInterval,
            isMainThreadUnresponsive, sleepInterval, &framesContributingToDelayCount);

        uint64_t framesDelayForTimeIntervalInNanos = timeIntervalToNanoseconds(delayDuration);

        BOOL isFullyBlocking = framesContributingToDelayCount == 1;

        if (isFullyBlocking && framesDelayForTimeIntervalInNanos >= timeoutIntervalInNanos) {
            SENTRY_LOG_WARN(@"App Hang detected: fully-blocking.");

            reported = YES;
            lastAppHangStartedSystemTime = dateProvider.systemTime;
            [self ANRDetected:kSentryANRTypeFullyBlocking];
        }

        NSTimeInterval nonFullyBlockingFramesDelayThreshold = self.timeoutInterval * 0.99;
        if (!isFullyBlocking && delayDuration > nonFullyBlockingFramesDelayThreshold) {

            SENTRY_LOG_WARN(@"App Hang detected: non-fully-blocking.");

            reported = YES;
            lastAppHangStartedSystemTime = dateProvider.systemTime;
            [self ANRDetected:kSentryANRTypeNonFullyBlocking];
        }
    }

    @synchronized(threadLock) {
        state = kSentryANRTrackerNotRunning;
        [self.threadWrapper threadFinished:threadID];
    }
}

- (void)ANRDetected:(SentryANRTypeInternal)type
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerInternalDelegate> target in localListeners) {
        [target anrDetected:type];
    }
}

- (void)ANRStopped:(NSTimeInterval)hangDurationMinimum to:(NSTimeInterval)hangDurationMaximum
{
    NSArray *targets;
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    SentryANRStoppedResultInternal *result =
        [[SentryANRStoppedResultInternal alloc] initWithMinDuration:hangDurationMinimum
                                                        maxDuration:hangDurationMaximum];
    for (id<SentryANRTrackerInternalDelegate> target in targets) {
        [target anrStopped:result];
    }
}

- (void)addListener:(id<SentryANRTrackerInternalDelegate>)listener
{
    @synchronized(self.listeners) {
        [self.listeners addObject:listener];

        @synchronized(threadLock) {
            if (self.listeners.count > 0 && state == kSentryANRTrackerNotRunning) {
                if (state == kSentryANRTrackerNotRunning) {
                    state = kSentryANRTrackerStarting;
                    [NSThread detachNewThreadSelector:@selector(detectANRs)
                                             toTarget:self
                                           withObject:nil];
                }
            }
        }
    }
}

- (void)removeListener:(id<SentryANRTrackerInternalDelegate>)listener
{
    @synchronized(self.listeners) {
        [self.listeners removeObject:listener];

        if (self.listeners.count == 0) {
            [self stop];
        }
    }
}

- (void)clear
{
    @synchronized(self.listeners) {
        [self.listeners removeAllObjects];
        [self stop];
    }
}

- (void)stop
{
    @synchronized(threadLock) {
        SENTRY_LOG_INFO(@"Stopping App Hang detection");
        state = kSentryANRTrackerStopping;
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
