#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryHub+Private.h"
#    import "SentryOptions+Private.h"
#    import "SentrySDK+Private.h"
#    import "SentrySessionReplayIntegration+Private.h"
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
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration pause];
}

- (void)resume
{
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration resume];
}

- (void)start
{
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];

    if (replayIntegration == nil) {
        replayIntegration = [[SentrySessionReplayIntegration alloc] init];

        SentryOptions *options = [[SentryOptions alloc] init];
        options.enableSwizzling = SentrySDK.currentHub.client.options.enableSwizzling;
        options.experimental.sessionReplay.sessionSampleRate = 1;
        __unused BOOL installed = [replayIntegration installWithOptions:options];

        [SentrySDK.currentHub addInstalledIntegration:replayIntegration
                                                 name:NSStringFromClass(SentrySessionReplay.class)];
    }

    [replayIntegration start];
}

- (void)stop
{
    SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration stop];
}

@end

#endif
