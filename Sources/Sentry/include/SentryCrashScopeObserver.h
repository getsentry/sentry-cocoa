#import "SentryDefines.h"
#import "SentryScopeObserver.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashScopeObserver : NSObject <SentryScopeObserver>
SENTRY_NO_INIT

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;

@end

NS_ASSUME_NONNULL_END
