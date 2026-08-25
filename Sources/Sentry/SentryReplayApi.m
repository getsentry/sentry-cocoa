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
    [self
        dispatchReplayCommand:^(
            SentrySessionReplayIntegration *replayIntegration) { [replayIntegration pause]; }
               createIfNeeded:NO
                  fullSession:NO];
}

- (void)resume
{
    SENTRY_LOG_INFO(@"[Session Replay] Resuming session");
    [self
        dispatchReplayCommand:^(
            SentrySessionReplayIntegration *replayIntegration) { [replayIntegration resume]; }
               createIfNeeded:NO
                  fullSession:NO];
}

- (void)start
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting session");
    [self
        dispatchReplayCommand:^(
            SentrySessionReplayIntegration *replayIntegration) { [replayIntegration start]; }
               createIfNeeded:YES
                  fullSession:YES];
}

- (void)startBuffering
{
    SENTRY_LOG_INFO(@"[Session Replay] Starting buffer");
    [self
        dispatchReplayCommand:^(SentrySessionReplayIntegration *replayIntegration) {
            [replayIntegration startBuffering];
        }
               createIfNeeded:YES
                  fullSession:NO];
}

- (void)flush
{
    SENTRY_LOG_INFO(@"[Session Replay] Flushing session");
    [self
        dispatchReplayCommand:^(
            SentrySessionReplayIntegration *replayIntegration) { [replayIntegration flush]; }
               createIfNeeded:YES
                  fullSession:YES];
}

- (void)stop
{
    SENTRY_LOG_INFO(@"[Session Replay] Stopping session");
    [self
        dispatchReplayCommand:^(
            SentrySessionReplayIntegration *replayIntegration) { [replayIntegration stop]; }
               createIfNeeded:NO
                  fullSession:NO];
}

- (void)dispatchReplayCommand:(void (^)(SentrySessionReplayIntegration *))command
               createIfNeeded:(BOOL)createIfNeeded
                  fullSession:(BOOL)fullSession
{
    dispatch_async(dispatch_get_main_queue(), ^{
        SentrySessionReplayIntegration *replayIntegration
            = (SentrySessionReplayIntegration *)[SentrySDKInternal.currentHub
                getInstalledIntegration:SentrySessionReplayIntegration.class];
        if (replayIntegration == nil && createIfNeeded
            && SentrySDKInternal.currentHub.client.options) {
            SentryOptions *currentOptions = SENTRY_UNWRAP_NULLABLE(
                SentryOptions, SentrySDKInternal.currentHub.client.options);
            SENTRY_LOG_DEBUG(@"[Session Replay] Initializing replay integration");
            replayIntegration = [[SentrySessionReplayIntegration alloc]
                initForManualUseWith:currentOptions
                        dependencies:SentryDependencyContainer.sharedInstance
                         fullSession:fullSession];
            [SentrySDKInternal.currentHub
                addInstalledIntegration:replayIntegration
                                   name:SentrySessionReplayIntegration.name];
        }
        if (replayIntegration != nil) {
            command(replayIntegration);
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
