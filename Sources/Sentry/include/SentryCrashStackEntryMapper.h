#import "SentryDefines.h"

@class SentryFrame;
@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashStackEntryMapper : NSObject
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic;

/** Maps a plain instruction address. Only call after all target threads have resumed. */
- (SentryFrame *)mapAddress:(uintptr_t)address;

@end

NS_ASSUME_NONNULL_END
