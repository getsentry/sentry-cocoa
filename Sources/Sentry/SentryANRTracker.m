#import "SentryANRTracker.h"
#import "SentryCrashWrapper.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryANRTracker ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDate;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) NSMutableSet<id<SentryANRTrackerDelegate>> *listeners;

@property (weak, nonatomic) NSThread *thread;

@end

@implementation SentryANRTracker {
    NSObject *threadLock;
    BOOL running;
}

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                               crashWrapper:(SentryCrashWrapper *)crashWrapper
                       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                              threadWrapper:(SentryThreadWrapper *)threadWrapper
{
    if (self = [super init]) {
        self.timeoutInterval = (double)SENTRY_ANR_TRACKER_TIMEOUT_MILLIS / 1000;
        self.currentDate = currentDateProvider;
        self.crashWrapper = crashWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.threadWrapper = threadWrapper;
        self.listeners = [NSMutableSet new];
        threadLock = [[NSObject alloc] init];
        running = false;
    }
    return self;
}

- (void)detectANRs
{
    NSThread.currentThread.name = @"io.sentry.anr-tracker";

    self.thread = NSThread.currentThread;

    BOOL wasPreviousANR = NO;

    while (![self.thread isCancelled]) {

        NSDate *blockDeadline =
            [[self.currentDate date] dateByAddingTimeInterval:self.timeoutInterval];

        __block BOOL blockExecutedOnMainThread = NO;
        [self.dispatchQueueWrapper dispatchOnMainQueue:^{ blockExecutedOnMainThread = YES; }];

        [self.threadWrapper sleepForTimeInterval:self.timeoutInterval];

        if (blockExecutedOnMainThread) {
            if (wasPreviousANR) {
                [SentryLog logWithMessage:@"ANR stopped." andLevel:kSentryLevelWarning];
                [self notifyEnd];
            }

            wasPreviousANR = NO;
            continue;
        }

        if (wasPreviousANR) {
            [SentryLog logWithMessage:@"Ignoring ANR because ANR is still ongoing."
                             andLevel:kSentryLevelDebug];
            continue;
        }

        // The blockDeadline should be roughly executed after the timeoutInterval even if there is
        // an ANR. If the app gets suspended this thread could sleep and wake up again. To avoid
        // false positives, we don't report ANRs if the delta is too big.
        NSTimeInterval deltaFromNowToBlockDeadline =
            [[self.currentDate date] timeIntervalSinceDate:blockDeadline];

        if (deltaFromNowToBlockDeadline >= self.timeoutInterval) {
            NSString *message =
                [NSString stringWithFormat:@"Ignoring ANR because the delta is too big: %f.",
                          deltaFromNowToBlockDeadline];
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
            continue;
        }

        if (![self.crashWrapper isApplicationInForeground]) {
            [SentryLog logWithMessage:@"Ignoring ANR because the app is in the background"
                             andLevel:kSentryLevelDebug];
            continue;
        }

        wasPreviousANR = YES;
        [SentryLog logWithMessage:@"ANR detected." andLevel:kSentryLevelWarning];
        [self notifyBegin];
    }
}

- (void)notifyBegin
{
    NSArray *targets = [NSArray new];
    @synchronized(self.listeners) {
        targets = [self.listeners allObjects];
    }

    for (id<SentryANRTrackerDelegate> target in targets) {
        [target anrDetected];
    }
}

- (void)notifyEnd
{
    NSArray *targets = [NSArray new];
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

        if (self.listeners.count > 0 && !running) {
            @synchronized(threadLock) {
                if (!running) {
                    [self start];
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

- (void)start
{
    @synchronized(threadLock) {
        [NSThread detachNewThreadSelector:@selector(detectANRs) toTarget:self withObject:nil];
        running = YES;
    }
}

- (void)stop
{
    @synchronized(threadLock) {
        [SentryLog logWithMessage:@"Stopping ANR detection" andLevel:kSentryLevelInfo];
        [self.thread cancel];
        running = NO;
    }
}

@end

NS_ASSUME_NONNULL_END
