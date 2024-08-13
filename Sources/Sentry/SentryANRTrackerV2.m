#import "SentryANRTrackerV2.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryFramesTracker.h"
#import "SentryLog.h"
#import "SentrySwift.h"
#import "SentryThreadWrapper.h"
#import "SentryTime.h"
#import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryANRTrackerState) {
    kSentryANRTrackerNotRunning = 1,
    kSentryANRTrackerRunning,
    kSentryANRTrackerStarting,
    kSentryANRTrackerStopping
};

@interface
SentryANRTrackerV2 ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSHashTable<id<SentryANRTrackerV2Delegate>> *listeners;
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end

@implementation SentryANRTrackerV2 {
    NSObject *threadLock;
    SentryANRTrackerState state;
}

- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
                           crashWrapper:(SentryCrashWrapper *)crashWrapper
                   dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                          threadWrapper:(SentryThreadWrapper *)threadWrapper
                          framesTracker:(SentryFramesTracker *)framesTracker
{
    if (self = [super init]) {
        self.timeoutInterval = timeoutInterval;
        self.crashWrapper = crashWrapper;
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

    SentryCurrentDateProvider *dateProvider = SentryDependencyContainer.sharedInstance.dateProvider;

    BOOL reported = NO;

    NSInteger reportThreshold = 5;
    NSTimeInterval sleepInterval = self.timeoutInterval / reportThreshold;
    uint64_t timeoutIntervalInNanos = timeIntervalToNanoseconds(self.timeoutInterval);

    uint64_t recoveryIntervalInNanos = timeIntervalToNanoseconds(sleepInterval * 2);
    CFTimeInterval recoverIntervalFramesDelayThreshold
        = nanosecondsToTimeInterval(recoveryIntervalInNanos) * 0.2;

    uint64_t lastAppHangStoppedSystemTime = dateProvider.systemTime - timeoutIntervalInNanos;

    // Canceling the thread can take up to sleepInterval.
    while (YES) {
        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        NSDate *sleepDeadline = [[dateProvider date] dateByAddingTimeInterval:self.timeoutInterval];

        [self.threadWrapper sleepForTimeInterval:sleepInterval];

        if (![self.crashWrapper isApplicationInForeground]) {
            SENTRY_LOG_DEBUG(@"Ignoring potential app hangs because the app is in the background");
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
            continue;
        }

        uint64_t frameDelayEndSystemTime = dateProvider.systemTime;
        uint64_t frameDelayStartSystemTime = frameDelayEndSystemTime - timeoutIntervalInNanos;

        SentryFramesDelayResult *framesDelayForTimeInterval =
            [self.framesTracker getFramesDelay:frameDelayStartSystemTime
                            endSystemTimestamp:frameDelayEndSystemTime];

        if (framesDelayForTimeInterval.delayDuration == -1) {
            continue;
        }

        uint64_t recoveryIntervalStartSystemTime
            = frameDelayEndSystemTime - recoveryIntervalInNanos;

        SentryFramesDelayResult *framesDelayForRecoveryInterval =
            [self.framesTracker getFramesDelay:recoveryIntervalStartSystemTime
                            endSystemTimestamp:frameDelayEndSystemTime];

        if (framesDelayForRecoveryInterval.delayDuration == -1) {
            continue;
        }

        //        SENTRY_LOG_DEBUG(@"App hang recovery: %f",
        //        framesDelayForRecoveryInterval.delayDuration);

        if (reported
            && framesDelayForRecoveryInterval.delayDuration < recoverIntervalFramesDelayThreshold) {
            SENTRY_LOG_DEBUG(
                @"App hang stopped with delay: %f", framesDelayForRecoveryInterval.delayDuration);

            // The App Hang stopped, don't block the App Hangs thread or the main thread with
            // calling ANRStopped listeners.
            [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{ [self ANRStopped]; }];

            lastAppHangStoppedSystemTime = dateProvider.systemTime;
            reported = NO;
        }

        uint64_t lastAppHangLongEnoughInPastThreshold
            = lastAppHangStoppedSystemTime + timeoutIntervalInNanos;

        if (dateProvider.systemTime < lastAppHangLongEnoughInPastThreshold) {
            continue;
        }

        if (reported) {
            continue;
        }

        uint64_t framesDelayForTimeIntervalInNanos
            = timeIntervalToNanoseconds(framesDelayForTimeInterval.delayDuration);

        BOOL isFullyBlocking = framesDelayForTimeInterval.framesContributingToDelayCount == 1;

        //        SENTRY_LOG_WARN(@"App Hang: Delay: %f", framesDelayForTimeInterval.delayDuration);

        if (isFullyBlocking && framesDelayForTimeIntervalInNanos >= timeoutIntervalInNanos) {

            reported = YES;

            SENTRY_LOG_WARN(@"App Hang detected: fully-blocking.");

            [self ANRDetected:kSentryANRTypeFullyBlocking];

            continue;
        }

        NSTimeInterval nonFullyBlockingFramesDelayThreshold = self.timeoutInterval * 0.95;
        if (!isFullyBlocking
            && framesDelayForTimeInterval.delayDuration > nonFullyBlockingFramesDelayThreshold) {

            reported = YES;

            SENTRY_LOG_WARN(@"App Hang detected: non-fully-blocking.");
            [self ANRDetected:kSentryANRTypeNonFullyBlocking];
        }
    }

    @synchronized(threadLock) {
        state = kSentryANRTrackerNotRunning;
        [self.threadWrapper threadFinished:threadID];
    }
}

- (void)ANRDetected:(SentryANRType)type
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerV2Delegate> target in localListeners) {
        [target anrDetected:type];
    }
}

- (void)ANRStopped
{
    NSArray *targets;
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerV2Delegate> target in targets) {
        [target anrStopped];
    }
}

- (void)addListener:(id<SentryANRTrackerV2Delegate>)listener
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

- (void)removeListener:(id<SentryANRTrackerV2Delegate>)listener
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
