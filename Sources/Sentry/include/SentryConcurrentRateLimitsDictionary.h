#import <Foundation/Foundation.h>
#import "SentryRateLimitCategory.h"

NS_ASSUME_NONNULL_BEGIN

/** A thread safe wrapper around a dictionary to store rate limits.
 */
@interface SentryConcurrentRateLimitsDictionary : NSObject

/**
 Adds the passed rate limits. If a rate limit already exists it is overwritten.
 @param rateLimits The key is the SentryRateLimitCategory. We use NSNumber because we can't use an enum.
    The value is valid until date
 */
- (void)addRateLimits:(NSDictionary<NSNumber *, NSDate *> *)rateLimits;

/** Returns the date until the rate limit is active. */
- (NSDate *)getRateLimitForCategory:(SentryRateLimitCategory)category;

@end

NS_ASSUME_NONNULL_END
