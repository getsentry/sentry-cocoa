#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RateLimitParser)
@interface SentryRateLimitParser : NSObject

+ (NSDictionary<NSString *, NSDate *> * _Nonnull)parse:(NSString *)header;

@end

NS_ASSUME_NONNULL_END
