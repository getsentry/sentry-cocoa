#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryLevelMapper.h"

@implementation SentryLevelHelper

+ (NSString *_Nonnull)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb
{
    return nameForSentryLevel(breadcrumb.level);
}

@end
