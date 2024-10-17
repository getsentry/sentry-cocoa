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
    // Start could be misused and called multiple times, causing it to
    // be initialized more than once before being installed.
    // Synchronizing it will prevent this problem.
    @synchronized (self) {
        SentrySessionReplayIntegration *replayIntegration
        = (SentrySessionReplayIntegration *)[SentrySDK.currentHub
                                             getInstalledIntegration:SentrySessionReplayIntegration.class];
        
        if (replayIntegration == nil) {
            SentryOptions *currentOptions = SentrySDK.currentHub.client.options;
            replayIntegration =
            [[SentrySessionReplayIntegration alloc] initForManualUse:currentOptions];
            
            [SentrySDK.currentHub addInstalledIntegration:replayIntegration
                                                     name:NSStringFromClass(SentrySessionReplay.class)];
        }
        
        [replayIntegration start];
    }
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
