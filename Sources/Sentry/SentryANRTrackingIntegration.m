#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryClient+Private.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashWrapper.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentrySDK+Private.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nonatomic, strong) SentryOptions *options;

@end

@implementation SentryANRTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];

    [self.tracker addListener:self];
    self.options = options;
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableAppHangTracking) {
        [SentryLog logWithMessage:@"Not going to enable App Hanging integration because "
                                  @"enableAppHangsTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (options.appHangTimeoutInterval == 0) {
        [SentryLog logWithMessage:@"Not going to enable App Hanging integration because "
                                  @"appHangsTimeoutInterval is 0."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    // In case the debugger is attached
    if ([SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced]) {
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    [self.tracker removeListener:self];
}

- (void)anrDetected
{
    SentryThreadInspector *threadInspector = SentrySDK.currentHub.getClient.threadInspector;

    NSString *message = [NSString stringWithFormat:@"App hanging for at least %li ms.",
                                  (long)(self.options.appHangTimeoutInterval * 1000)];

    NSArray<SentryThread *> *threads = [threadInspector getCurrentThreadsWithStackTrace];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException = [[SentryException alloc] initWithValue:message
                                                                         type:@"App Hanging"];
    sentryException.mechanism = [[SentryMechanism alloc] initWithType:@"AppHang"];
    sentryException.stacktrace = [threads[0] stacktrace];
    [threads enumerateObjectsUsingBlock:^(SentryThread *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { obj.current = [NSNumber numberWithBool:idx == 0]; }];

    event.exceptions = @[ sentryException ];
    event.threads = threads;

    [SentrySDK captureEvent:event];
}

- (void)anrStopped
{
    // We dont report when an ANR ends.
}

@end

NS_ASSUME_NONNULL_END
