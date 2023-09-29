#import "MockUIScene.h"
#if UIKIT_LINKED
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
