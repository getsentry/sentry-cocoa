#import "SentryUIViewControllerSanitizer.h"
#import "SentryDependencyContainer.h"
#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@implementation SentryUIViewControllerSanitizer

+ (NSString *)sanitizeViewControllerName:(id)controller
{
    if ([controller isKindOfClass:[NSObject class]]) {
        controller = [(NSObject *)controller class];
    }

    return [SentryDependencyContainer.sharedInstance.descriptor getDescription:controller];
}

@end
