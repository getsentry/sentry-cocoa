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
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration pause];
}

- (void)resume
{
    SENTRY_LOG_INFO(@"[Session Replay] Resuming session");
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration resume];
}

- (void)start SENTRY_DISABLE_THREAD_SANITIZER("double-checked lock produce false alarms")
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting session");
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];

    // Start could be misused and called multiple times, causing it to
    // be initialized more than once before being installed.
    // Synchronizing it will prevent this problem.
    if (replayIntegration == nil) {
        @synchronized(self) {
            replayIntegration = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
                getInstalledIntegration:SentrySessionReplayIntegration.class];
            if (replayIntegration == nil && SentrySDKInternal.currentHub.client.options) {
                SentryOptions *currentOptions = SENTRY_UNWRAP_NULLABLE(
                    SentryOptions, SentrySDKInternal.currentHub.client.options);
                SentryDependencyContainer *sharedContainer =
                    [SentryDependencyContainer sharedInstance];
                if (![SentrySessionReplay
                        shouldEnableSessionReplayWithEnvironmentChecker:
                            [sharedContainer sessionReplayEnvironmentChecker]
                                                    experimentalOptions:currentOptions
                                                                            .experimental]) {
                    SENTRY_LOG_ERROR(@"[Session Replay] Session replay is disabled due to "
                                     @"environment potentially causing PII leaks.");
                    return;
                }
                SENTRY_LOG_DEBUG(@"[Session Replay] Initializing replay integration");

                replayIntegration =
                    [[SentrySessionReplayIntegration alloc] initForManualUseWith:currentOptions
                                                                    dependencies:sharedContainer];

                [SentrySDKInternal.currentHub
                    addInstalledIntegration:(id<SentryIntegrationProtocol>)replayIntegration
                                       name:[SentrySessionReplayIntegration name]];
            }
        }
    }
    [replayIntegration start];
}

- (void)stop
{
    SENTRY_LOG_INFO(@"[Session Replay] Stopping session");
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
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
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];

    [replayIntegration showMaskPreview:opacity];
}

- (void)hideMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Hiding mask preview");
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];

    [replayIntegration hideMaskPreview];
}

@end

#endif
