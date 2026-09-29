#import <Foundation/Foundation.h>

#if !SDK_V10

@protocol SentryScopeObserver;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashScopeHelper : NSObject

#    if SWIFT_PACKAGE
// The Swift test utilities restore the Swift-owned SentryScopeObserver return type.
+ (NSObject *)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
    NS_SWIFT_NAME(makeScopeObserver(maxBreadcrumbs:));
#    else
+ (id<SentryScopeObserver>)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs;
#    endif

@end

NS_ASSUME_NONNULL_END

#endif
