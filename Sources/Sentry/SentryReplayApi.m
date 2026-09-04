#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

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
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration pause]; }];
}

- (void)resume
{
    SENTRY_LOG_INFO(@"[Session Replay] Resuming session");
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration resume]; }];
}

- (void)start
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting session");
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration start]; }];
}

- (void)startBuffering
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting buffer");
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration startBuffering]; }];
}

- (void)flush
{
    SENTRY_LOG_INFO(@"[Session Replay] Flushing session");
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration flush]; }];
}

- (void)stop
{
    SENTRY_LOG_INFO(@"[Session Replay] Stopping session");
    [self dispatchReplayCommand:^(
        SentrySessionReplayIntegration *replayIntegration) { [replayIntegration stop]; }];
}

- (void)dispatchReplayCommand:(void (^)(SentrySessionReplayIntegration *))command
{
    dispatch_async(dispatch_get_main_queue(), ^{
        SentrySessionReplayIntegration *replayIntegration
            = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
                getInstalledIntegration:SentrySessionReplayIntegration.class];
        if (replayIntegration != nil) {
            command(replayIntegration);
        } else {
            SENTRY_LOG_WARN(@"[Session Replay] Cannot execute command because the Session "
                            @"Replay integration is not installed.");
        }
    });
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
