#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"

@implementation SentryLevelBridge : NSObject
+ (NSUInteger) breadcrumbLevel:(SentryBreadcrumb *)breadcrumb {
    return breadcrumb.level;
}
@end
