#import "SentryScreenShot.h"


#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>

@implementation SentryScreenShot {
    UIWindow * _mainWindow;
}

- (NSData*)imageForScreen {
    if (_mainWindow == nil) {
        [self retrieveMainWindow];
    }
    return  nil;
}

- (void)retrieveMainWindow {
    
}

@end

#endif
