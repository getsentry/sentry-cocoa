#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSFileManagerSwizzlingHelper : NSObject

+ (void)swizzleWithTracker:(SENTRY_SWIFT_MIGRATION_ID(SentryFileIOTracker))tracker;

+ (void)unswizzle;

@end

NS_ASSUME_NONNULL_END
