#import <Foundation/Foundation.h>
#import "SentryRateLimits.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Implements only rate limits with status code 429. Needs to be updated.
*/
NS_SWIFT_NAME(DefaultRateLimits)
@interface SentryDefaultRateLimits : NSObject <SentryRateLimits>

- (BOOL)isRateLimitReached:(NSString *)type;

- (void)update:(NSHTTPURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
