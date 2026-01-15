#import <Foundation/Foundation.h>

@protocol SentryScopeObserver;

@interface SentryCrashScopeHelper : NSObject

+ (id<SentryScopeObserver>)getScopeObserverWithMaxBreacdrumb:(NSInteger)maxBreadcrumbs;

@end
