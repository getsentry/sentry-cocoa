#import "SentryCrashScopeHelper.h"

#if !SDK_V10
#    import "SentryCrashScopeObserver.h"

@implementation SentryCrashScopeHelper

+ (NSObject *)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
{
    return [[SentryCrashScopeObserver alloc] initWithMaxBreadcrumbs:maxBreadcrumbs];
}

@end

#endif
