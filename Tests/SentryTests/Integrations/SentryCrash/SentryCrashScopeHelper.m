#import "SentryCrashScopeHelper.h"
#import "SentryCrashScopeObserver.h"
#import "SentrySwift.h"

@interface SentryCrashScopeObserver (SentryScopeObserver)
@end

@implementation SentryCrashScopeHelper

+ (id<SentryScopeObserver>)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
{
    return (id<SentryScopeObserver>)[[SentryCrashScopeObserver alloc]
        initWithMaxBreadcrumbs:maxBreadcrumbs];
}

@end
