#import "SentryUIApplication.h"

//#if SENTRY_HAS_UIKIT

@implementation SentryUIApplication

+ (UIApplication *)sharedApplication {
    if (![UIApplication respondsToSelector:@selector(sharedApplication)])
        return nil;

    return [UIApplication performSelector:@selector(sharedApplication)];
}

+ (NSArray<UIWindow *> *)windows {
    UIApplication* app = SentryUIApplication.sharedApplication;
    if (app == nil)
        return nil;
    
    if ([app.delegate respondsToSelector:@selector(window)]) {
        return @[app.delegate.window];
    }
    
    if (@available(iOS 13.0, *)) {
        if ([app respondsToSelector:@selector(connectedScenes)]) {
            NSMutableArray* result = [NSMutableArray new];
            
            for (UIScene* scene in app.connectedScenes) {
                if (scene.delegate && [scene.delegate respondsToSelector:@selector(window)]) {
                    [result addObject:[scene.delegate performSelector:@selector(window)]];
                }
            }
            
            return result;
        }
    }
    
    return nil;
}

@end

//#endif
