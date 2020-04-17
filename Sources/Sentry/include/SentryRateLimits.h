#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// TODO: implement new Rate Limit strategy.
/*
 * Parses http responses from the Sentry server for rate limits.
 * The server sends either a 429 status code or a custom header
 * "X-Sentry-Rate-Limits".
 * If the server communicates that a rate limit is reached this
 * component saves the rate limit and returns NO for
 * isRateLimitReached.
 */
NS_SWIFT_NAME(RateLimits)
@protocol SentryRateLimits <NSObject>

- (BOOL)isRateLimitReached;

- (void)update:(NSHTTPURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
