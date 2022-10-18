#import "SentryUIViewControllerSanitizer.h"
#import "SentrySwift.h"

@implementation SentryUIViewControllerSanitizer

+ (NSString *)sanitizeViewControllerName:(id)controller
{
    return [SwiftDescriptor getDescription:controller];
}

@end
