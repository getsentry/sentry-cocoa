#import "SentryReplayApi.h"
#import "SentryReplayApi+Private.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalCDefines.h"
#    import "SentryLogC.h"
#    import "SentryOptions+Private.h"
#    import "SentrySDK+Private.h"
#    import "SentrySessionReplayIntegration+Private.h"
#    import "SentrySwift.h"
#    import "_SentryDispatchQueueWrapperInternal.h"
#    import <UIKit/UIKit.h>

@interface SentryReplayApi ()

@property (nonatomic, strong) _SentryDispatchQueueWrapperInternal *dispatchQueueWrapper;

- (nullable SentrySessionReplayIntegration *)installedIntegration;

@end

@implementation SentryReplayApi

- (instancetype)initPrivateWithDispatchQueueWrapper:
    (_SentryDispatchQueueWrapperInternal *)dispatchQueueWrapper
{
    if (self = [super init]) {
        _dispatchQueueWrapper = dispatchQueueWrapper;
    }
    return self;
}

#    if SENTRY_TEST || SENTRY_TEST_CI
- (instancetype)initWithDispatchQueueWrapper:
    (_SentryDispatchQueueWrapperInternal *)dispatchQueueWrapper
{
    return [self initPrivateWithDispatchQueueWrapper:dispatchQueueWrapper];
}
#    endif

- (nullable SentrySessionReplayIntegration *)installedIntegration
{
    return (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
        getInstalledIntegration:SentrySessionReplayIntegration.class];
}

- (void)maskView:(UIView *)view
{
    // UIView operations must be performed on the main thread
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [SentryRedactViewHelper maskView:view]; }];
}

- (void)unmaskView:(UIView *)view
{
    // UIView operations must be performed on the main thread
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [SentryRedactViewHelper unmaskView:view]; }];
}

- (void)pause
{
    SENTRY_LOG_INFO(@"[Session Replay] Pausing session");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [[weakSelf installedIntegration] pause]; }];
}

- (void)resume
{
    SENTRY_LOG_INFO(@"[Session Replay] Resuming session");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [[weakSelf installedIntegration] resume]; }];
}

- (void)start SENTRY_DISABLE_THREAD_SANITIZER("double-checked lock produce false alarms")
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting session");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
            return;

        SentrySessionReplayIntegration *replayIntegration = [strongSelf installedIntegration];

        // Start could be misused and called multiple times, causing it to
        // be initialized more than once before being installed.
        // Synchronizing it will prevent this problem.
        if (replayIntegration == nil) {
            @synchronized(strongSelf) {
                replayIntegration = [strongSelf installedIntegration];
                if (replayIntegration == nil) {
                    SENTRY_LOG_DEBUG(@"[Session Replay] Initializing replay integration");
                    SentryOptions *currentOptions = SentrySDKInternal.currentHub.client.options;
                    replayIntegration =
                        [[SentrySessionReplayIntegration alloc] initForManualUse:currentOptions];

                    [SentrySDKInternal.currentHub
                        addInstalledIntegration:replayIntegration
                                           name:NSStringFromClass(SentrySessionReplay.class)];
                }
            }
        }
        [replayIntegration start];
    }];
}

- (void)stop
{
    SENTRY_LOG_INFO(@"[Session Replay] Stopping session");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [[weakSelf installedIntegration] stop]; }];
}

- (void)showMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Showing mask preview");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper dispatchSyncOnMainQueue:^{ [weakSelf showMaskPreview:1]; }];
}

- (void)showMaskPreview:(CGFloat)opacity
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Showing mask preview with opacity: %f", opacity);
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [[weakSelf installedIntegration] showMaskPreview:opacity]; }];
}

- (void)hideMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Hiding mask preview");
    // Session replay operations may involve UIKit operations that must be performed on the main
    // thread
    __weak typeof(self) weakSelf = self;
    [self.dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{ [[weakSelf installedIntegration] hideMaskPreview]; }];
}

#    if SENTRY_TEST || SENTRY_TEST_CI
// Test-only method to access the dispatch queue wrapper for verification
- (_SentryDispatchQueueWrapperInternal *)getDispatchQueueWrapper
{
    return _dispatchQueueWrapper;
}
#    endif

@end

#endif
