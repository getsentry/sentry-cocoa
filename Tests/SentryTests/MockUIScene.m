#import "MockUIScene.h"
#if SENTRY_HAS_UIKIT
@implementation MockUIScene

- (instancetype)init
{
    return self;
}

- (UISceneActivationState)activationState
{
    return UISceneActivationStateForegroundActive;
}

@end
#endif
