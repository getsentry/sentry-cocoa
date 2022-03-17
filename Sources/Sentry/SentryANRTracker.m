#import "SentryANRTracker.h"
#import "SentryCrashWrapper.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@interface
SentryANRTracker ()

@property (weak, nonatomic) id<SentryANRTrackerDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDate;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;

@property (weak, nonatomic) NSThread *thread;

@end

@implementation SentryANRTracker

- (instancetype)initWithDelegate:(id<SentryANRTrackerDelegate>)delegate
           timeoutIntervalMillis:(NSUInteger)timeoutIntervalMillis
             currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                    crashWrapper:(SentryCrashWrapper *)crashWrapper
            dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                   threadWrapper:(SentryThreadWrapper *)threadWrapper
{
    if (self = [super init]) {
        self.delegate = delegate;
        self.timeoutInterval = (double)timeoutIntervalMillis / 1000;
        self.currentDate = currentDateProvider;
        self.crashWrapper = crashWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.threadWrapper = threadWrapper;
    }
    return self;
}

- (void)start
{
    [NSThread detachNewThreadSelector:@selector(detectANRs) toTarget:self withObject:nil];
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
                [self.delegate anrStopped];
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
        [self.delegate anrDetected];
    }
}

- (void)stop
{
    [SentryLog logWithMessage:@"Stopping ANR detection" andLevel:kSentryLevelInfo];
    [self.thread cancel];
}

@end

#endif

NS_ASSUME_NONNULL_END
