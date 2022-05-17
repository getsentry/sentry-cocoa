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

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;

@end

@implementation SentryANRTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.crashWrapper = dependencies.crashWrapper;

    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.appStateManager = dependencies.appStateManager;
    self.tracker = dependencies.anrTracker;
    self.tracker.timeoutInterval = options.anrTimeoutInterval;
    
    [self.tracker addListener:self];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableOutOfMemoryTracking) {
        return YES;
    }

    // In case the debugger is attached
    if ([self.crashWrapper isBeingTraced]) {
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
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = YES; }];
}

- (void)anrStopped
{
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = NO; }];
}

@end

#endif

NS_ASSUME_NONNULL_END
