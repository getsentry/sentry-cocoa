#import <Foundation/Foundation.h>
#import "SentryRateLimits.h"

@class SentryRetryAfterHeaderParser;

NS_ASSUME_NONNULL_BEGIN

/**
 Parses http responses from the Sentry server for rate limits and stores rate limits
 in memory. The server can communicate a rate limit either through a 429 status
 code with a "Retry-After" header or through any response with a custom
 "X-Sentry-Rate-Limits" header.
*/
NS_SWIFT_NAME(DefaultRateLimits)
@interface SentryDefaultRateLimits : NSObject <SentryRateLimits>

- (instancetype) initWithParsers:(SentryRetryAfterHeaderParser *)retryAfterHeaderParser;

- (BOOL)isRateLimitActive:(NSString *_Nonnull)type;

- (void)update:(NSHTTPURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
