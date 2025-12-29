#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryClient.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalCDefines.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentrySDK+Private.h"
#    import "SentrySwift.h"
#    import <UIKit/UIKit.h>

@implementation SentryReplayApi

- (void)maskView:(UIView *)view
{
    [SentryRedactViewHelper maskView:view];
}

- (void)unmaskView:(UIView *)view
{
    [SentryRedactViewHelper unmaskView:view];
}

- (void)pause
{
    SENTRY_LOG_INFO(@"[Session Replay] Pausing session");
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];
    [replayIntegration pause];
}

- (void)resume
{
    SENTRY_LOG_INFO(@"[Session Replay] Resuming session");
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];
    [replayIntegration resume];
}

- (void)start SENTRY_DISABLE_THREAD_SANITIZER("double-checked lock produce false alarms")
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting session");
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];

    // Start could be misused and called multiple times, causing it to
    // be initialized more than once before being installed.
    // Synchronizing it will prevent this problem.
    if (replayIntegration == nil) {
        @synchronized(self) {
            replayIntegration = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
                getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];
            if (replayIntegration == nil && SentrySDKInternal.currentHub.client.options) {
                SentryOptions *currentOptions = SENTRY_UNWRAP_NULLABLE(
                    SentryOptions, SentrySDKInternal.currentHub.client.options);
                SentryDependencyContainer *sharedContainer =
                    [SentryDependencyContainer sharedInstance];
                if (![SentrySessionReplayIntegrationObjC
                           shouldEnableFor:currentOptions
                        environmentChecker:[sharedContainer sessionReplayEnvironmentChecker]]) {
                    SENTRY_LOG_ERROR(@"[Session Replay] Session replay is disabled due to "
                                     @"environment potentially causing PII leaks.");
                    return;
                }
                SENTRY_LOG_DEBUG(@"[Session Replay] Initializing replay integration");

                replayIntegration = [[SentrySessionReplayIntegrationObjC alloc]
                    initForManualUseWithOptions:currentOptions
                                   dependencies:sharedContainer];

                [SentrySDKInternal.currentHub
                    addInstalledIntegration:(id<SentryIntegrationProtocol>)replayIntegration
                                       name:NSStringFromClass(
                                                SentrySessionReplayIntegrationObjC.class)];
            }
        }
    }
    [replayIntegration start];
}

- (void)stop
{
    SENTRY_LOG_INFO(@"[Session Replay] Stopping session");
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];
    [replayIntegration stop];
}

- (void)showMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Showing mask preview");
    [self showMaskPreview:1];
}

- (void)showMaskPreview:(CGFloat)opacity
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Showing mask preview with opacity: %f", opacity);
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];

    [replayIntegration showMaskPreview:opacity];
}

- (void)hideMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Hiding mask preview");
    SentrySessionReplayIntegrationObjC *replayIntegration
        = (SentrySessionReplayIntegrationObjC *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegrationObjC.class];

    [replayIntegration hideMaskPreview];
}

@end

#endif
