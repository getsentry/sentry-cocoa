#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@interface SentryNSDataSwizzling : NSObject

+ (void)startWithOptions:(SentryOptions *)options;

+ (void)stop;

@end

NS_ASSUME_NONNULL_END
