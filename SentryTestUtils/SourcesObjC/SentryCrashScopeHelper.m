#import "SentryCrashScopeHelper.h"

#if !SDK_V10
#    import "SentryCrashScopeObserver.h"
#    import "SentrySwift.h"

@implementation SentryCrashScopeHelper

#    if SWIFT_PACKAGE
+ (NSObject *)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
#    else
+ (id<SentryScopeObserver>)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
#    endif
{
    return (id<SentryScopeObserver>)[[SentryCrashScopeObserver alloc]
        initWithMaxBreadcrumbs:maxBreadcrumbs];
}

@end

#endif
