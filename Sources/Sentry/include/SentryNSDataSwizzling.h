#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@interface SentryNSDataSwizzling : SENTRY_BASE_OBJECT
SENTRY_NO_INIT

@property (class, readonly) SentryNSDataSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
