#import <Foundation/Foundation.h>

#if !SDK_V10

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashScopeHelper : NSObject

// The Swift test utilities restore the Swift-owned SentryScopeObserver return type.
+ (NSObject *)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs
    NS_SWIFT_NAME(makeScopeObserver(maxBreadcrumbs:));

@end

NS_ASSUME_NONNULL_END

#endif
