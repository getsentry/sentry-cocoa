#import "SentryDefines.h"
#import "SentryScopeObserver.h"

@class SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOutOfMemoryScopeObserver : NSObject <SentryScopeObserver>
SENTRY_NO_INIT

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager;

@end

NS_ASSUME_NONNULL_END
