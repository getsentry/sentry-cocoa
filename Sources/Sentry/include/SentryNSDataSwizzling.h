#import "SentryDefines.h"
#import "SentryFileIOTracker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@interface SentryNSDataSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSDataSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker;

@end

NS_ASSUME_NONNULL_END
