#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryHub+Private.h"
#    import "SentrySDK+Private.h"
#    import "SentrySessionReplayIntegration.h"
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
    SentrySessionReplayIntegration *replayIntegration =
        [SentrySDK.currentHub getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration pause];
}

- (void)resume
{
    SentrySessionReplayIntegration *replayIntegration =
        [SentrySDK.currentHub getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration resume];
}

@end

#endif
