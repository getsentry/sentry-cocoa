#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSDataSwizzlingHelper : NSObject

+ (void)swizzleWithTracker:(SENTRY_SWIFT_MIGRATION_ID(SentryFileIOTracker))tracker;

+ (void)stop;

#if defined(DEBUG) // Test support.
+ (BOOL)swizzlingActive;
#endif

@end

NS_ASSUME_NONNULL_END
