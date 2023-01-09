#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOptions (HybridSDKs)

- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
