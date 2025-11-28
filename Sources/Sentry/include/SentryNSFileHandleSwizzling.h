#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;
@class SentryFileIOTracker;

@interface SentryNSFileHandleSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSFileHandleSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
