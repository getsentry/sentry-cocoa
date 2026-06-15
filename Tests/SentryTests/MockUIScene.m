#import "MockUIScene.h"
#if SENTRY_HAS_UIKIT

@interface MockUISceneSession ()
@property (nonatomic, copy) UISceneSessionRole sentry_role;
@end

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

@implementation MockUISceneSession

- (instancetype)initWithRole:(UISceneSessionRole)role
{
    self.sentry_role = role;
    return self;
}

- (UISceneSessionRole)role
{
    return self.sentry_role;
}

@end

@interface MockUIWindowScene ()
@property (nonatomic, strong) MockUISceneSession *sentry_session;
@end

@implementation MockUIWindowScene

- (instancetype)initWithSessionRole:(UISceneSessionRole)role
{
    self.sentry_session = [[MockUISceneSession alloc] initWithRole:role];
    return self;
}

- (UISceneActivationState)activationState
{
    return UISceneActivationStateForegroundActive;
}

- (UISceneSession *)session
{
    return self.sentry_session;
}

@end
#endif
