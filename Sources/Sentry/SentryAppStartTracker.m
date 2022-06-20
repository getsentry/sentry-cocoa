#import "SentryAppStartMeasurement.h"
#import "SentryAppStateManager.h"
#import "SentryLog.h"
#import "SentrySysctl.h"
#import <Foundation/Foundation.h>
#import <PrivateSentrySDKOnly.h>
#import <SentryAppStartTracker.h>
#import <SentryAppState.h>
#import <SentryCurrentDateProvider.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryInternalNotificationNames.h>
#import <SentryLog.h>
#import <SentrySDK+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

static NSDate *runtimeInit = nil;

/**
 * The watchdog usually kicks in after an app hanging 10 to 20 seconds. As the app could hang in
 * multiple stages during the launch we pick a higher threshold.
 */
static const NSTimeInterval SENTRY_APP_START_MAX_DURATION = 60.0;

@interface
SentryAppStartTracker ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDate;
@property (nonatomic, strong) SentryAppState *previousAppState;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentrySysctl *sysctl;
@property (nonatomic, assign) BOOL wasInBackground;
@property (nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end

@implementation SentryAppStartTracker

+ (void)load
{
    // Invoked whenever this class is added to the Objective-C runtime.
    runtimeInit = [NSDate date];
}

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                            appStateManager:(SentryAppStateManager *)appStateManager
                                     sysctl:(SentrySysctl *)sysctl
{
    if (self = [super init]) {
        self.currentDate = currentDateProvider;
        self.dispatchQueue = dispatchQueueWrapper;
        self.appStateManager = appStateManager;
        self.sysctl = sysctl;
        self.previousAppState = [self.appStateManager loadCurrentAppState];
        self.wasInBackground = NO;
        self.didFinishLaunchingTimestamp = [currentDateProvider date];
    }
    return self;
}

- (void)start
{
    // It can happen that the OS posts the didFinishLaunching notification before we register for it
    // or we just don't receive it. In this case the didFinishLaunchingTimestamp would be nil. As
    // the SDK should be initialized in application:didFinishLaunchingWithOptions: or in the init of
    // @main of a SwiftUI  we set the timestamp here.
    self.didFinishLaunchingTimestamp = [self.currentDate date];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didFinishLaunching)
                                               name:UIApplicationDidFinishLaunchingNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeVisible)
                                               name:UIWindowDidBecomeVisibleNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];

    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        [self buildAppStartMeasurement];
    }
}

- (void)buildAppStartMeasurement
{
    void (^block)(void) = ^(void) {
        [self stop];

        SentryAppStartType appStartType = [self getStartType];

        if (appStartType == SentryAppStartTypeUnknown) {
            [SentryLog logWithMessage:@"Unknown start type. Not measuring app start."
                             andLevel:kSentryLevelWarning];
            return;
        }

        if (self.wasInBackground) {
            // If the app was already running in the background it's not a cold or warm
            // start.
            [SentryLog logWithMessage:@"App was in background. Not measuring app start."
                             andLevel:kSentryLevelInfo];
            return;
        }

        // According to a talk at WWDC about optimizing app launch
        // (https://devstreaming-cdn.apple.com/videos/wwdc/2019/423lzf3qsjedrzivc7/423/423_optimizing_app_launch.pdf?dl=1
        // slide 17) no process exists for cold and warm launches. Since iOS 15, though, the system
        // might decide to pre-warm your app before the user tries to open it. Therefore we use the
        // process start timestamp only if it's not too long ago. The process start time returned
        // valid values when testing with real devices before iOS 15. See:
        // https://developer.apple.com/documentation/uikit/app_and_environment/responding_to_the_launch_of_your_app/about_the_app_launch_sequence#3894431
        // https://developer.apple.com/documentation/metrickit/mxapplaunchmetric,
        // https://twitter.com/steipete/status/1466013492180312068,
        // https://github.com/MobileNativeFoundation/discussions/discussions/146

        NSTimeInterval appStartDuration =
            [[self.currentDate date] timeIntervalSinceDate:self.sysctl.processStartTimestamp];

        if (appStartDuration >= SENTRY_APP_START_MAX_DURATION) {
            NSString *message = [NSString
                stringWithFormat:
                    @"The app start exceeded the max duration of %f seconds. Not measuring app "
                    @"start.\nThis could be because the OS prewarmed the app's process.",
                SENTRY_APP_START_MAX_DURATION];
            [SentryLog logWithMessage:message andLevel:kSentryLevelInfo];
            return;
        }

        // On HybridSDKs, we miss the didFinishLaunchNotification and the
        // didBecomeVisibleNotification. Therefore, we can't set the
        // didFinishLaunchingTimestamp, and we can't calculate the appStartDuration. Instead,
        // the SDK provides the information we know and leaves the rest to the HybridSDKs.
        if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
            self.didFinishLaunchingTimestamp =
                [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:0];

            appStartDuration = 0;
        }

        SentryAppStartMeasurement *appStartMeasurement =
            [[SentryAppStartMeasurement alloc] initWithType:appStartType
                                          appStartTimestamp:self.sysctl.processStartTimestamp
                                                   duration:appStartDuration
                                       runtimeInitTimestamp:runtimeInit
                                didFinishLaunchingTimestamp:self.didFinishLaunchingTimestamp];

        SentrySDK.appStartMeasurement = appStartMeasurement;
    };

    // With only running this once we know that the process is a new one when the following
    // code is executed.
// We need to make sure the block runs on each test instead of only once
#    if TEST
    block();
#    else
    static dispatch_once_t once;
    [self.dispatchQueue dispatchOnce:&once block:block];
#    endif
}

/**
 * This is when the first frame is drawn.
 */
- (void)didBecomeVisible
{
    [self buildAppStartMeasurement];
}

- (SentryAppStartType)getStartType
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
    // first time. If the previous boot time is in the future most likely the system time
    // changed and we can't to anything.
    return SentryAppStartTypeUnknown;
}

- (void)didFinishLaunching
{
    self.didFinishLaunchingTimestamp = [self.currentDate date];
}

- (void)didEnterBackground
{
    self.wasInBackground = YES;
}

- (void)stop
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/**
 * Needed for testing, not public.
 */
- (void)setRuntimeInit:(NSDate *)value
{
    runtimeInit = value;
}

@end

#endif
