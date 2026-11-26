#import "SceneDelegate.h"
@import SentrySampleShared;

@interface SceneDelegate ()
@property (strong, nonatomic) SampleAppDebugMenu *debugMenu;
@end

@implementation SceneDelegate

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    if (self.debugMenu == nil) {
        self.debugMenu = [[SampleAppDebugMenu alloc] init];
    }
    [self.debugMenu displayIn:(UIWindowScene *)scene];
}

@end
