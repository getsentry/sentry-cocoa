#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryCrashWrapper.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>
#import "SentrySDK+Private.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryCrashMachineContext.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryThreadInspector.h"
#import "SentryMechanism.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

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

    self.tracker = SentryDependencyContainer.sharedInstance.anrTracker;
    self.tracker.timeoutInterval = options.anrTimeoutInterval;
    
    [self.tracker addListener:self];
    self.options = options;
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.anrEnable) {
        return YES;
    }

    // In case the debugger is attached
//    if ([SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced]) {
//        return YES;
//    }

    return NO;
}

- (void)uninstall
{
    [self.tracker removeListener:self];
}

- (void)anrDetected
{
    NSString * message = [NSString stringWithFormat:@"Application Not Responding for at least %li ms.", (NSUInteger)(self.options.anrTimeoutInterval * 1000)];
    
    NSArray<SentryThread *> * threads = [SentrySDK.currentHub.getClient.threadInspector getCurrentThreadsWithStackTrace:YES];
    
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException = [[SentryException alloc] initWithValue:message
                                                                         type:@"App Hanging"];
    sentryException.mechanism = [[SentryMechanism alloc] initWithType:@"anr"];
    
    event.exceptions = @[ sentryException ];
    event.threads = threads;
        
    [SentrySDK captureEvent:event];
}

- (void)anrStopped
{
    
}

@end

#endif

NS_ASSUME_NONNULL_END
