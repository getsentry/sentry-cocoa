#import "SentryCrashSysCtl.h"
#import "SentryDependencyContainer.h"
#import "SentrySysctl.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryCrashWrapper.h>
#import <SentryCurrentDateProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryFileManager.h>
#import <SentryNSNotificationCenterWrapper.h>
#import <SentryOptions.h>

#if SENTRY_HAS_UIKIT
#    import <SentryInternalNotificationNames.h>
#    import <UIKit/UIKit.h>
#endif

@interface
SentryAppStateManager ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic) NSInteger startCount;

@end

@implementation SentryAppStateManager

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashWrapper:(SentryCrashWrapper *)crashWrapper
                    fileManager:(SentryFileManager *)fileManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.options = options;
        self.crashWrapper = crashWrapper;
        self.fileManager = fileManager;
        self.dispatchQueue = dispatchQueueWrapper;
        self.startCount = 0;
    }
    return self;
}

#if SENTRY_HAS_UIKIT

- (void)start
{
    if (self.startCount == 0) {
        SentryNSNotificationCenterWrapper *notificationCenterWrapper
            = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
        [notificationCenterWrapper
            addObserver:self
               selector:@selector(didBecomeActive)
                   name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName];

        [notificationCenterWrapper addObserver:self
                                      selector:@selector(didBecomeActive)
                                          name:SentryHybridSdkDidBecomeActiveNotificationName];

        [notificationCenterWrapper
            addObserver:self
               selector:@selector(willResignActive)
                   name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName];

        [notificationCenterWrapper
            addObserver:self
               selector:@selector(willTerminate)
                   name:SentryNSNotificationCenterWrapper.willTerminateNotificationName];

        [self storeCurrentAppState];
    }

    self.startCount += 1;
}

- (void)stop
{
    [self stopWithForce:NO];
}

// forceStop is YES when the SDK gets closed
- (void)stopWithForce:(BOOL)forceStop
{
    if (self.startCount <= 0) {
        return;
    }

    if (forceStop) {
        [self
            updateAppStateInBackground:^(SentryAppState *appState) { appState.isSDKRunning = NO; }];

        self.startCount = 0;
    } else {
        self.startCount -= 1;
    }

    if (self.startCount == 0) {
        // Remove the observers with the most specific detail possible, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        SentryNSNotificationCenterWrapper *notificationCenterWrapper
            = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
        [notificationCenterWrapper
            removeObserver:self
                      name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName];

        [notificationCenterWrapper removeObserver:self
                                             name:SentryHybridSdkDidBecomeActiveNotificationName];

        [notificationCenterWrapper
            removeObserver:self
                      name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName];

        [notificationCenterWrapper
            removeObserver:self
                      name:SentryNSNotificationCenterWrapper.willTerminateNotificationName];
    }
}

- (void)dealloc
{
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:self];
}

/**
 * It is called when an app is receiving events / it is in the foreground and when we receive a
 * @c SentryHybridSdkDidBecomeActiveNotification.
 * @discussion This also works when using SwiftUI or Scenes, as UIKit posts a
 * @c didBecomeActiveNotification regardless of whether your app uses scenes, see
 * https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622956-applicationdidbecomeactive.
 */
- (void)didBecomeActive
{
    [self updateAppStateInBackground:^(SentryAppState *appState) { appState.isActive = YES; }];
}

/**
 * The app is about to lose focus / going to the background. This is only called when an app was
 * receiving events / was is in the foreground.
 */
- (void)willResignActive
{
    [self updateAppStateInBackground:^(SentryAppState *appState) { appState.isActive = NO; }];
}

- (void)willTerminate
{
    // The app is terminating so it is fine to do this on the main thread.
    // Furthermore, so users can manually post UIApplicationWillTerminateNotification and then call
    // exit(0), to avoid getting false OOM when using exit(0), see GH-1252.
    [self updateAppState:^(SentryAppState *appState) { appState.wasTerminated = YES; }];
}

- (void)updateAppStateInBackground:(void (^)(SentryAppState *))block
{
    // We accept the tradeoff that the app state might not be 100% up to date over blocking the main
    // thread.
    [self.dispatchQueue dispatchAsyncWithBlock:^{ [self updateAppState:block]; }];
}

- (void)updateAppState:(void (^)(SentryAppState *))block
{
    @synchronized(self) {
        SentryAppState *appState = [self.fileManager readAppState];
        if (appState != nil) {
            block(appState);
            [self.fileManager storeAppState:appState];
        }
    }
}

- (SentryAppState *)buildCurrentAppState
{
    // Is the current process being traced or not? If it is a debugger is attached.
    bool isDebugging = self.crashWrapper.isBeingTraced;

    NSString *vendorId = [UIDevice.currentDevice.identifierForVendor UUIDString];

    return [[SentryAppState alloc] initWithReleaseName:self.options.releaseName
                                             osVersion:UIDevice.currentDevice.systemVersion
                                              vendorId:vendorId
                                           isDebugging:isDebugging
                                   systemBootTimestamp:SentryDependencyContainer.sharedInstance
                                                           .sysctlWrapper.systemBootTimestamp];
}

- (SentryAppState *)loadPreviousAppState
{
    return [self.fileManager readPreviousAppState];
}

- (void)storeCurrentAppState
{
    [self.fileManager storeAppState:[self buildCurrentAppState]];
}

#endif

@end
