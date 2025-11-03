#import "SentryCrashSysCtl.h"
#import "SentryNotificationNames.h"
#import <SentryDefaultAppStateManager.h>
#import <SentryOptionsInternal.h>
#import <SentrySwift.h>

#if SENTRY_HAS_UIKIT
#    import <SentryInternalNotificationNames.h>
#    import <UIKit/UIKit.h>
#endif

@interface SentryDefaultAppStateManager ()

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) id<SentryNSNotificationCenterWrapper> notificationCenterWrapper;
@property (nonatomic, copy) void (^storeCurrent)(void);
@property (nonatomic, copy) void (^updateTerminated)(void);
@property (nonatomic, copy) void (^updateSDKNotRunning)(void);
@property (nonatomic, copy) void (^updateActive)(BOOL);
@property (nonatomic) NSInteger startCount;

@end

@implementation SentryDefaultAppStateManager

- (instancetype)initWithStoreCurrent:(void (^)(void))storeCurrent
                    updateTerminated:(void (^)(void))updateTerminated
                 updateSDKNotRunning:(void (^)(void))updateSDKNotRunning
                        updateActive:(void (^)(BOOL))updateActive
{
    if (self = [super init]) {
        self.dispatchQueue = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
        self.notificationCenterWrapper
            = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
        self.storeCurrent = storeCurrent;
        self.updateTerminated = updateTerminated;
        self.updateSDKNotRunning = updateSDKNotRunning;
        self.updateActive = updateActive;
        self.startCount = 0;
    }
    return self;
}

#if SENTRY_HAS_UIKIT

- (void)start
{
    if (self.startCount == 0) {
        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:SentryDidBecomeActiveNotification
                                             object:nil];

        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:SentryHybridSdkDidBecomeActiveNotificationName
                                             object:nil];

        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(willResignActive)
                                               name:SentryWillResignActiveNotification
                                             object:nil];

        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(willTerminate)
                                               name:SentryWillTerminateNotification
                                             object:nil];

        self.storeCurrent();
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
        [self.dispatchQueue dispatchAsyncWithBlock:^{ self.updateSDKNotRunning(); }];

        self.startCount = 0;
    } else {
        self.startCount -= 1;
    }

    if (self.startCount == 0) {
        // Remove the observers with the most specific detail possible, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        [self.notificationCenterWrapper removeObserver:self
                                                  name:SentryDidBecomeActiveNotification
                                                object:nil];

        [self.notificationCenterWrapper
            removeObserver:self
                      name:SentryHybridSdkDidBecomeActiveNotificationName
                    object:nil];

        [self.notificationCenterWrapper removeObserver:self
                                                  name:SentryWillResignActiveNotification
                                                object:nil];

        [self.notificationCenterWrapper removeObserver:self
                                                  name:SentryWillTerminateNotification
                                                object:nil];
    }
}

- (void)dealloc
{
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [self.notificationCenterWrapper removeObserver:self name:nil object:nil];
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
    [self.dispatchQueue dispatchAsyncWithBlock:^{ self.updateActive(YES); }];
}

/**
 * The app is about to lose focus / going to the background. This is only called when an app was
 * receiving events / was is in the foreground.
 */
- (void)willResignActive
{
    [self.dispatchQueue dispatchAsyncWithBlock:^{ self.updateActive(NO); }];
}

- (void)willTerminate
{
    // The app is terminating so it is fine to do this on the main thread.
    // Furthermore, so users can manually post UIApplicationWillTerminateNotification and then call
    // exit(0), to avoid getting false watchdog terminations when using exit(0), see GH-1252.
    self.updateTerminated();
}

#endif

@end
