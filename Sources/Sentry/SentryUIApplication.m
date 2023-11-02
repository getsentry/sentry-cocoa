#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@implementation SentryUIApplication {
    UIApplicationState appState;
}

- (instancetype)init{
    if (self = [super init]) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didEnterBackground)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didBecomeActive)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
        //We store the application state when the app is initialized
        //and we keep track of its changes by the notifications
        //this way we avoid calling sharedApplication in a background thread
        appState = self.sharedApplication.applicationState;
    }
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UIApplication *)sharedApplication
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)])
        return nil;

    return [UIApplication performSelector:@selector(sharedApplication)];
}

- (nullable id<UIApplicationDelegate>)getApplicationDelegate:(UIApplication *)application
{
    return application.delegate;
}

- (NSArray<UIScene *> *)getApplicationConnectedScenes:(UIApplication *)application
    API_AVAILABLE(ios(13.0), tvos(13.0))
{
    if (application && [application respondsToSelector:@selector(connectedScenes)]) {
        return [application.connectedScenes allObjects];
    }

    return @[];
}

- (NSArray<UIWindow *> *)windows
{
    UIApplication *app = [self sharedApplication];
    NSMutableArray *result = [NSMutableArray array];

    if (@available(iOS 13.0, tvOS 13.0, *)) {
        NSArray<UIScene *> *scenes = [self getApplicationConnectedScenes:app];
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && scene.delegate &&
                [scene.delegate respondsToSelector:@selector(window)]) {
                id window = [scene.delegate performSelector:@selector(window)];
                if (window) {
                    [result addObject:window];
                }
            }
        }
    }

    id<UIApplicationDelegate> appDelegate = [self getApplicationDelegate:app];

    if ([appDelegate respondsToSelector:@selector(window)] && appDelegate.window != nil) {
        [result addObject:appDelegate.window];
    }

    return result;
}

- (UIApplicationState)applicationState
{
    return appState;
}

- (void)didEnterBackground {
    appState = UIApplicationStateBackground;
}

- (void)didBecomeActive {
    appState = UIApplicationStateActive;
}

@end

#endif // SENTRY_HAS_UIKIT
