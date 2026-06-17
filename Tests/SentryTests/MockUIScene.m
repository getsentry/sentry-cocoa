// See MockUIScene.h for why these mocks are in ObjC.

#import "MockUIScene.h"
#if SENTRY_HAS_UIKIT
@implementation MockUIScene

- (instancetype)init
{
    // Intentionally skip super.init to avoid UISceneSession requirement.
    return self;
}

- (UISceneActivationState)activationState
{
    return UISceneActivationStateForegroundActive;
}

@end

@implementation MockUIWindowScene

- (instancetype)init
{
    // Intentionally skip super.init to avoid UISceneSession requirement.
    return self;
}

- (UISceneActivationState)activationState
{
    return UISceneActivationStateForegroundActive;
}

@end
#endif
