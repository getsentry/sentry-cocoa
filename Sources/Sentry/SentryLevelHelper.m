#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"

@implementation SentryLevelBridge : NSObject
+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb
{
    return breadcrumb.level;
}

+ (void)setBreadcrumbLevel:(SentryBreadcrumb *)breadcrumb level:(NSUInteger)level
{
    breadcrumb.level = level;
}
@end
