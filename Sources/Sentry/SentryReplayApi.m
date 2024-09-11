#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentrySessionReplayIntegration.h"
#    import "SentrySwift.h"
#    import <UIKit/UIKit.h>

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
    [SentrySessionReplayIntegration.installed pause];
}

- (void)resume
{
    [SentrySessionReplayIntegration.installed resume];
}

@end

#endif
