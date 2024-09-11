#import "SentryReplay.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentrySessionReplayIntegration.h"
#    import "SentrySwift.h"
#    import <UIKit/UIKit.h>

@implementation SentryReplay

- (void)replayRedactView:(UIView *)view
{
    [SentryRedactViewHelper redactView:view];
}

- (void)replayIgnoreView:(UIView *)view
{
    [SentryRedactViewHelper ignoreView:view];
}

- (void)pause
{
    [SentrySessionReplayIntegration.installed pause];
}

- (void)resume
{
    [SentrySessionReplayIntegration.installed resume];
}

@end

#endif
