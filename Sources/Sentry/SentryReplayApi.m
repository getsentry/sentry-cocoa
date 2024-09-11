#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentrySessionReplayIntegration.h"
#    import "SentrySwift.h"
#    import <UIKit/UIKit.h>
#    import "SentryHub+Private.h"
#    import "SentrySDK+Private.h"

@implementation SentryReplayApi

- (void)redactView:(UIView *)view
{
    [SentryRedactViewHelper redactView:view];
}

- (void)ignoreView:(UIView *)view
{
    [SentryRedactViewHelper ignoreView:view];
}

- (void)pause
{
    SentrySessionReplayIntegration * replayIntegration = [SentrySDK.currentHub getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration pause];
}

- (void)resume
{
    SentrySessionReplayIntegration * replayIntegration = [SentrySDK.currentHub getInstalledIntegration:SentrySessionReplayIntegration.class];
    [replayIntegration resume];
}

@end

#endif
