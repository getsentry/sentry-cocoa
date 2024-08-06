#import "SentryANRTracker.h"
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
SentryANRTracker ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSHashTable<id<SentryANRTrackerDelegate>> *listeners;
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end

@implementation SentryANRTracker {
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

    BOOL reported = NO;
    BOOL framesDelayReachNonFullyBlockingThreshold = NO;

    NSInteger reportThreshold = 5;
    NSTimeInterval sleepInterval = self.timeoutInterval / reportThreshold;

    SentryCurrentDateProvider *dateProvider = SentryDependencyContainer.sharedInstance.dateProvider;

    // Canceling the thread can take up to sleepInterval.
    while (YES) {
        @synchronized(threadLock) {
            if (state != kSentryANRTrackerRunning) {
                break;
            }
        }

        NSDate *blockDeadline = [[dateProvider date] dateByAddingTimeInterval:self.timeoutInterval];

        [self.threadWrapper sleepForTimeInterval:sleepInterval];

        if (![self.crashWrapper isApplicationInForeground]) {
            SENTRY_LOG_DEBUG(@"Ignoring potential ANRs because the app is in the background");
            continue;
        }

        // The blockDeadline should be roughly executed after the timeoutInterval even if there is
        // an ANR. If the app gets suspended this thread could sleep and wake up again. To avoid
        // false positives, we don't report ANRs if the delta is too big.
        NSTimeInterval deltaFromNowToBlockDeadline =
            [[dateProvider date] timeIntervalSinceDate:blockDeadline];

        if (deltaFromNowToBlockDeadline >= self.timeoutInterval) {
            SENTRY_LOG_DEBUG(
                @"Ignoring ANR because the delta is too big: %f.", deltaFromNowToBlockDeadline);
            continue;
        }

        uint64_t nowSystemTimeStamp = dateProvider.systemTime;

        uint64_t frameDelayStartSystemTimestamp
            = nowSystemTimeStamp - timeIntervalToNanoseconds(self.timeoutInterval);

        CFTimeInterval framesDelay =
            [self.framesTracker getFramesDelay:frameDelayStartSystemTimestamp
                            endSystemTimestamp:nowSystemTimeStamp];

        uint64_t sleepIntervalStartedSystemTimestamp
            = nowSystemTimeStamp - timeIntervalToNanoseconds(sleepInterval);

        CFTimeInterval framesDelayForThisSleepInterval =
            [self.framesTracker getFramesDelay:sleepIntervalStartedSystemTimestamp
                            endSystemTimestamp:nowSystemTimeStamp];

        if (framesDelayForThisSleepInterval < sleepInterval * 0.3) {

            if (reported) {
                SENTRY_LOG_DEBUG(@"ANRR stopped.");

                // The ANR stopped, don't block the main thread with calling ANRStopped listeners.
                // While the ANR code reports an ANR and collects the stack trace, the ANR might
                // stop simultaneously. In that case, the ANRs stack trace would contain the
                // following code running on the main thread. To avoid this, we offload work to a
                // background thread.
                [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{ [self ANRStopped]; }];
            }

            reported = NO;
            framesDelayReachNonFullyBlockingThreshold = NO;
        }

        NSTimeInterval framesDelayThreshold = self.timeoutInterval * 0.9;
        if (fabs(framesDelay - self.timeoutInterval) < 0.001 && !reported) {
            reported = YES;

            SENTRY_LOG_WARN(@"ANR detected: fully-blocking.");
            [self ANRDetected:kSentryANRTypeFullyBlocking];
        } else if (framesDelay > framesDelayThreshold && !reported) {

            if (!framesDelayReachNonFullyBlockingThreshold) {
                framesDelayReachNonFullyBlockingThreshold = YES;
            } else {
                reported = YES;

                SENTRY_LOG_WARN(@"ANR detected: non-fully-blocking.");
                [self ANRDetected:kSentryANRTypeNonFullyBlocking];
            }
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

    for (id<SentryANRTrackerDelegate> target in localListeners) {
        [target anrDetected:type];
    }
}

- (void)ANRStopped
{
    NSArray *targets;
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerDelegate> target in targets) {
        [target anrStopped];
    }
}

- (void)addListener:(id<SentryANRTrackerDelegate>)listener
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

- (void)removeListener:(id<SentryANRTrackerDelegate>)listener
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
        SENTRY_LOG_INFO(@"Stopping ANR detection");
        state = kSentryANRTrackerStopping;
    }
}

@end

NS_ASSUME_NONNULL_END
