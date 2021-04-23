#import <SentryOptions.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptions (Private)

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

@end

NS_ASSUME_NONNULL_END
