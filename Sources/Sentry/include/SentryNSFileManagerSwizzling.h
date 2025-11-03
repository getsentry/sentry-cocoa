#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptionsInternal;
@class SentryFileIOTracker;

@interface SentryNSFileManagerSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSFileManagerSwizzling *shared;

- (void)startWithOptions:(SentryOptionsInternal *)options tracker:(SentryFileIOTracker *)tracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
