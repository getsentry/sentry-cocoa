#import "SentryDefines.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashWrapper.h>
#import <SentryDefaultCurrentDateProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryHub.h>
#import <SentryLog.h>
#import <SentryOptions+Private.h>
#import <SentryOutOfMemoryLogic.h>
#import <SentryOutOfMemoryTracker.h>
#import <SentryOutOfMemoryTrackingIntegration.h>
#import <SentrySDK+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOutOfMemoryTrackingIntegration ()

@property (nonatomic, strong) SentryOutOfMemoryTracker *tracker;
@property (nonatomic, strong) SentryANRTracker *anrTracker;
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;

@end

@implementation SentryOutOfMemoryTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
        self.testConfigurationFilePath
            = NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"];
    }
    return self;
}

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueueWrapper =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-out-of-memory-tracker"
                                              attributes:attributes];

    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;
    SentryCrashWrapper *crashWrapper = [SentryDependencyContainer sharedInstance].crashWrapper;
    SentryOutOfMemoryLogic *logic =
        [[SentryOutOfMemoryLogic alloc] initWithOptions:options
                                           crashAdapter:crashWrapper
                                        appStateManager:appStateManager];

    self.tracker = [[SentryOutOfMemoryTracker alloc] initWithOptions:options
                                                    outOfMemoryLogic:logic
                                                     appStateManager:appStateManager
                                                dispatchQueueWrapper:dispatchQueueWrapper
                                                         fileManager:fileManager];
    [self.tracker start];

    self.anrTracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];
    [self.anrTracker addListener:self];

    self.appStateManager = appStateManager;
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableOutOfMemoryTracking) {
        return YES;
    }

    // The testConfigurationFilePath is not nil when running unit tests. This doesn't work for UI
    // tests though.
    if (self.testConfigurationFilePath) {
        [SentryLog logWithMessage:@"Won't track OOMs, because detected that unit tests are running."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
    [self.anrTracker removeListener:self];
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
