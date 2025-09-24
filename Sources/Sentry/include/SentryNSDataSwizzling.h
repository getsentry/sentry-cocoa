#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@protocol SentryFileIOTracking;

@interface SentryNSDataSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSDataSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options tracker:(id<SentryFileIOTracking>)tracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
