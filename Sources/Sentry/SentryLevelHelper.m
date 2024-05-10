#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"

@implementation SentryLevelHelper

+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb
{
    return breadcrumb.level;
}

@end
