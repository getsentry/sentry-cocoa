#import "SentryAppStartTrackingIntegration.h"
#import "SentryAppStartTracker.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import <Foundation/Foundation.h>
#import <PrivateSentrySDKOnly.h>
#import <SentryAppStateManager.h>
#import <SentryCrashWrapper.h>
#import <SentryDependencyContainer.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentrySysctl.h>

@interface
SentryAppStartTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryAppStartTracker *tracker;
#endif

@end

@implementation SentryAppStartTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
        ]]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    SentryDefaultCurrentDateProvider *currentDateProvider =
        [SentryDefaultCurrentDateProvider sharedInstance];
    SentrySysctl *sysctl = [[SentrySysctl alloc] init];

    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;

    self.tracker = [[SentryAppStartTracker alloc]
        initWithCurrentDateProvider:currentDateProvider
               dispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                    appStateManager:appStateManager
                             sysctl:sysctl];
    [self.tracker start];

#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryAppStartTracker will not track app start up time."
                     andLevel:kSentryLevelDebug];
#endif
}

#if SENTRY_HAS_UIKIT
- (BOOL)shouldBeEnabled:(NSArray *)options;
{
    // If the cocoa SDK is being used by a hybrid SDK,
    // we install App start tracking and let the hybrid SDK decide what to do.
    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        return YES;
    }

    return [super shouldBeEnabled:options];
}
#endif

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    if (nil != self.tracker) {
        [self.tracker stop];
    }
#endif
}

@end
