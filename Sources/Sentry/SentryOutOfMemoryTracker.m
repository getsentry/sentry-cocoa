#import "SentryFileManager.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryHub.h>
#import <SentryInternalNotificationNames.h>
#import <SentryLog.h>
#import <SentryMechanism.h>
#import <SentryMessage.h>
#import <SentryNSNotificationCenterWrapper.h>
#import <SentryOptions.h>
#import <SentryOutOfMemoryLogic.h>
#import <SentryOutOfMemoryTracker.h>
#import <SentrySDK+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@interface
SentryOutOfMemoryTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryOutOfMemoryLogic *outOfMemoryLogic;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryOutOfMemoryTracker

- (instancetype)initWithOptions:(SentryOptions *)options
               outOfMemoryLogic:(SentryOutOfMemoryLogic *)outOfMemoryLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.options = options;
        self.outOfMemoryLogic = outOfMemoryLogic;
        self.appStateManager = appStateManager;
        self.dispatchQueue = dispatchQueueWrapper;
        self.fileManager = fileManager;
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(didBecomeActive)
               name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName
             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:SentryHybridSdkDidBecomeActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(willResignActive)
               name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName
             object:nil];

    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(willTerminate)
               name:SentryNSNotificationCenterWrapper.willTerminateNotificationName
             object:nil];

    [self.dispatchQueue dispatchAsyncWithBlock:^{
        if ([self.outOfMemoryLogic isOOM]) {
            SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];
            // Set to empty list so no breadcrumbs of the current scope are added
            event.breadcrumbs = @[];

            SentryException *exception =
                [[SentryException alloc] initWithValue:SentryOutOfMemoryExceptionValue
                                                  type:SentryOutOfMemoryExceptionType];
            SentryMechanism *mechanism =
                [[SentryMechanism alloc] initWithType:SentryOutOfMemoryMechanismType];
            mechanism.handled = @(NO);
            exception.mechanism = mechanism;
            event.exceptions = @[ exception ];

            // We don't need to upate the releaseName of the event to the previous app state as we
            // assume it's not an OOM when the releaseName changed between app starts.
            [SentrySDK captureCrashEvent:event];
        }

        [self.appStateManager storeCurrentAppState];
    }];

#else
    SENTRY_LOG_INFO(@"NO UIKit -> SentryOutOfMemoryTracker will not track OOM.");
    return;
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    // Remove the observers with the most specific detail possible, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [NSNotificationCenter.defaultCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName
                object:nil];

    [NSNotificationCenter.defaultCenter
        removeObserver:self
                  name:SentryHybridSdkDidBecomeActiveNotificationName
                object:nil];

    [NSNotificationCenter.defaultCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.willResignActiveNotificationName
                object:nil];

    [NSNotificationCenter.defaultCenter
        removeObserver:self
                  name:SentryNSNotificationCenterWrapper.willTerminateNotificationName
                object:nil];
    [self.appStateManager deleteAppState];
#endif
}

#if SENTRY_HAS_UIKIT
- (void)dealloc
{
    [self stop];
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/**
 * It is called when an App. is receiving events / It is in the foreground and when we receive a
 * SentryHybridSdkDidBecomeActiveNotification.
 */
- (void)didBecomeActive
{
    [self updateAppState:^(SentryAppState *appState) { appState.isActive = YES; }];
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
    // The app is terminating so it is fine to do this on the main thread.
    // Furthermore, so users can manually post UIApplicationWillTerminateNotification and then call
    // exit(0), to avoid getting false OOM when using exit(0), see GH-1252.
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.wasTerminated = YES; }];
}

- (void)updateAppState:(void (^)(SentryAppState *))block
{
    // We accept the tradeoff that the app state might not be 100% up to date over blocking the main
    // thread.
    [self.dispatchQueue dispatchAsyncWithBlock:^{ [self.appStateManager updateAppState:block]; }];
}

#endif

@end
