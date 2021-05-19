#import "SentryAppStartMeasurement.h"
#import "SentryAppStateManager.h"
#import "SentryLog.h"
#import "SentrySysctl.h"
#import <Foundation/Foundation.h>
#import <SentryAppStartTracker.h>
#import <SentryAppState.h>
#import <SentryClient+Private.h>
#import <SentryCurrentDateProvider.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryFileManager.h>
#import <SentryHub.h>
#import <SentryInternalNotificationNames.h>
#import <SentryLog.h>
#import <SentrySDK+Private.h>
#import <SentrySpan.h>

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@interface
SentryAppStartTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDate;
@property (nonatomic, strong) SentryAppState *previousAppState;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentrySysctl *sysctl;
@property (nonatomic, assign) BOOL wasInBackground;

@end

@implementation SentryAppStartTracker

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                appStateManager:(SentryAppStateManager *)appStateManager
                         sysctl:(SentrySysctl *)sysctl
{
    if (self = [super init]) {
        self.options = options;
        self.currentDate = currentDateProvider;
        self.dispatchQueue = dispatchQueueWrapper;
        self.appStateManager = appStateManager;
        self.sysctl = sysctl;
#    if SENTRY_HAS_UIKIT
        self.previousAppState = [self.appStateManager loadCurrentAppState];
#    endif
        self.wasInBackground = NO;
    }
    return self;
}

- (void)start
{
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:SentryHybridSdkDidBecomeActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
}

/**
 * It is called when an App. is receiving events / It is in the foreground and when we receive a
 * SentryHybridSdkDidBecomeActiveNotification.
 */
- (void)didBecomeActive
{
    // With only running this once we know that the process is a new one when the following code is
    // executed.
    static dispatch_once_t once;
    [self.dispatchQueue
        dispatchOnce:&once
               block:^{
                   NSString *appStartType = [self getStartType];

                   if ([appStartType isEqualToString:SentryAppStartTypeUnkown]) {
                       [SentryLog logWithMessage:@"Unknown start type. Not measuring app start."
                                        andLevel:kSentryLevelWarning];
                   } else if (self.wasInBackground) {
                       // If the app was already running in the background it's not a cold or warm
                       // start.
                       [SentryLog logWithMessage:@"App was in background. Not measuring app start."
                                        andLevel:kSentryLevelInfo];
                   } else {
                       NSTimeInterval appStartTime = [[self.currentDate date]
                           timeIntervalSinceDate:self.sysctl.processStartTimestamp];

                       [SentryLog logWithMessage:[NSString stringWithFormat:@"AppStart: sys:%f",
                                                           appStartTime]
                                        andLevel:kSentryLevelInfo];

                       SentryAppStartMeasurement *appStartMeasurement =
                           [[SentryAppStartMeasurement alloc] initWithType:appStartType
                                                                  duration:appStartTime];
                       SentrySDK.appStartMeasurement = appStartMeasurement;
                   }
               }];

    [self stop];
}

- (NSString *)getStartType
{
    // App launched the first time
    if (self.previousAppState == nil) {
        return SentryAppStartTypeCold;
    }

    SentryAppState *currentAppState = [self.appStateManager buildCurrentAppState];

    // If the release name is different we assume it's an app upgrade
    if (![currentAppState.releaseName isEqualToString:self.previousAppState.releaseName]) {
        return SentryAppStartTypeCold;
    }

    NSTimeInterval intervalSincePreviousBootTime = [self.previousAppState.systemBootTimestamp
        timeIntervalSinceDate:currentAppState.systemBootTimestamp];

    // System rebooted, because the previous boot time is in the past.
    if (intervalSincePreviousBootTime < 0) {
        return SentryAppStartTypeCold;
    }

    // System didn't reboot, previous and current boot time are the same.
    if (intervalSincePreviousBootTime == 0) {
        return SentryAppStartTypeWarm;
    }

    // This should never be reached as we unsubscribe to didBecomeActive after it is called the
    // first time. If the previous boot time is in the future most likely the system time changed
    // and we can't to anything.
    return SentryAppStartTypeUnkown;
}

- (void)didEnterBackground
{
    self.wasInBackground = YES;
}

- (void)stop
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end

#endif
