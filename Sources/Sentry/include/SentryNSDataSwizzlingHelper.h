#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSDataSwizzlingHelper : NSObject

+ (void)swizzleWithTracker:(SENTRY_SWIFT_MIGRATION_ID(SentryFileIOTracker))tracker;

+ (void)stop;

#if SENTRY_TEST || SENTRY_TEST_CI
+ (BOOL)swizzlingActive;
#endif

@end

NS_ASSUME_NONNULL_END
