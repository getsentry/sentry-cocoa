#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@interface SentryNSFileManagerSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSFileManagerSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
