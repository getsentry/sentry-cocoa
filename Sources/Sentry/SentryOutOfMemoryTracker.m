#import "SentryFileManager.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryClient+Private.h>
#import <SentryCrashAdapter.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryHub.h>
#import <SentryInternalNotificationNames.h>
#import <SentryLog.h>
#import <SentryMechanism.h>
#import <SentryMessage.h>
#import <SentryOptions.h>
#import <SentryOutOfMemoryTracker.h>
#import <SentrySDK+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@interface
SentryOutOfMemoryTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;

@end

@implementation SentryOutOfMemoryTracker : NSObject

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
{
    if (self = [super init]) {
        self.options = options;
        self.crashAdapter = crashAdatper;
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:SentryHybridSdkDidBecomeActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willResignActive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willTerminate)
                                               name:UIApplicationWillTerminateNotification
                                             object:nil];

    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppState *previousAppState = [fileManager readAppState];

    // Is the current process being traced or not? If it is a debugger is attached.
    bool isDebugging = self.crashAdapter.isBeingTraced;

    SentryAppState *currentAppState =
        [[SentryAppState alloc] initWithAppVersion:self.options.releaseName
                                         osVersion:UIDevice.currentDevice.systemVersion
                                       isDebugging:isDebugging];
    [fileManager storeAppState:currentAppState];

    // If there is no previous app state, we can't do anything.
    if (nil == previousAppState) {
        return;
    }

    // If the app version is different we assume it's an upgrade
    if (![currentAppState.appVersion isEqualToString:previousAppState.appVersion]) {
        return;
    }

    // The OS was upgraded
    if (![currentAppState.osVersion isEqualToString:previousAppState.osVersion]) {
        return;
    }

    // Restarting the app in development is a termination we can't catch and would falsely report
    // OOMs.
    if (previousAppState.isDebugging) {
        return;
    }

    // The app was terminated normally
    if (previousAppState.wasTerminated) {
        return;
    }

    // The app crashed on the previous run. No OOM.
    if (self.crashAdapter.crashedLastLaunch) {
        return;
    }

    // Was the app in foreground/active ?
    // If the app was in background we can't reliably tell if it was an OOM or not.
    if (!previousAppState.isActive) {
        return;
    }

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];
    // Set to empty list so no breadcrumbs of the current scope are added
    event.breadcrumbs = @[];

    NSString *exceptionType = @"Out Of Memory";
    SentryException *exception = [[SentryException alloc]
        initWithValue:
            @"The OS most likely terminated your app because it over-used RAM."
                 type:exceptionType];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:exceptionType];
    mechanism.handled = @(NO);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    [SentrySDK captureCrashEvent:event];

#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryOutOfMemoryTracker will not track OOM."
                     andLevel:kSentryLevelInfo];
    return;
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter removeObserver:self];
#endif
}

/**
 * It is called when an App. is receiving events / It is in the foreground and when we receive a
 * SentryHybridSdkDidBecomeActiveNotification.
 */
- (void)didBecomeActive
{
    // We don't know if the hybrid SDKs post the notification from a background thread, so we
    // synchronize to be safe.
    @synchronized(self) {
        [self updateAppState:^(SentryAppState *appState) { appState.isActive = YES; }];
    }
}

/**
 * The app is about to lose focus / going to the background. This is only called when an app was
 * receiving events / was is in the foreground.
 */
- (void)willResignActive
{
    [self updateAppState:^(SentryAppState *appState) { appState.isActive = NO; }];
}

- (void)willTerminate
{
    [self updateAppState:^(SentryAppState *appState) { appState.wasTerminated = YES; }];
}

- (void)updateAppState:(void (^)(SentryAppState *))block
{
    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppState *appState = [fileManager readAppState];
    if (nil != appState) {
        block(appState);
        [fileManager storeAppState:appState];
    }
}

@end
