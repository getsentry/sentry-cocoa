#import "SentryUIViewControllerSanitizer.h"
#import "SentrySwift.h"

@implementation SentryUIViewControllerSanitizer

+ (NSString *)sanitizeViewControllerName:(id)controller
{
    NSString *description = [NSString stringWithFormat:@"%@", controller];

    return [SwiftDescriptor getDescription:description];
}

@end
