#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptionsInternal;
@class SentryFileIOTracker;

@interface SentryNSDataSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSDataSwizzling *shared;

- (void)startWithOptions:(SentryOptionsInternal *)options tracker:(SentryFileIOTracker *)tracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
