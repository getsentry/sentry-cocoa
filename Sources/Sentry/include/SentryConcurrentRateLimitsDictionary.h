#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
    A thread safe wrapper around a dictionary to store rate limits.
 */
@interface SentryConcurrentRateLimitsDictionary : NSObject

/**
 Adds the passed rate limits. If a rate limit already exists it is overwritten.
 @param rateLimits key is the type and value is valid until date
 */
- (void)addRateLimits:(NSDictionary<NSString *, NSDate *> *)rateLimits;

/** Returns the date until the rate limit is active. */
- (NSDate *)getRateLimitForCategory:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
