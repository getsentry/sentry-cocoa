#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryCrashAdapter.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryCrashAdapter.h>
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * As we only use the ANR tracking integration for detecting falsely reported OOMs we can use a more
 * defensive value, because we are not reporting any ANRs.
 */
static NSUInteger const SENTRY_ANR_TRACKER_TIMEOUT_MILLIS = 2000;

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryCrashAdapter *crashWrapper;
#if TEST
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;
#endif

@end

@implementation SentryANRTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
#if TEST
        self.testConfigurationFilePath
            = NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"];
#endif
    }
    return self;
}

- (void)installWithOptions:(SentryOptions *)options
{
    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.crashWrapper = dependencies.crashAdapter;

    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.appStateManager = dependencies.appStateManager;

    self.tracker =
        [[SentryANRTracker alloc] initWithDelegate:self
                             timeoutIntervalMillis:SENTRY_ANR_TRACKER_TIMEOUT_MILLIS
                               currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                                      crashAdapter:dependencies.crashAdapter
                              dispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                                     threadWrapper:dependencies.threadWrapper];
    [self.tracker start];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
#if TEST
    // The testConfigurationFilePath is not nil when running unit tests. This doesn't work for UI
    // tests though.
    if (self.testConfigurationFilePath) {
        [SentryLog logWithMessage:@"Won't track ANRs, because detected that unit tests are running."
                         andLevel:kSentryLevelDebug];
        return YES;
    }
#endif

#if SENTRY_HAS_UIKIT
    if (!options.enableOutOfMemoryTracking) {
        return YES;
    }

    if ([self.crashWrapper isBeingTraced]) {
        return YES;
    }

    return NO;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryANRTrackingIntegration will not track ANRs, "
                              @"because we only track them to avoid false positives OOMs."
                     andLevel:kSentryLevelInfo];
    return YES;
#endif
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

- (void)anrDetected
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = YES; }];
#endif
}

- (void)anrStopped
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = NO; }];
#endif
}

@end

NS_ASSUME_NONNULL_END
