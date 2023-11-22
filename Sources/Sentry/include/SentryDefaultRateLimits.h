#import "SentryDefines.h"
#import "SentryRateLimits.h"

@class SentryRetryAfterHeaderParser;
@class SentryRateLimitParser;

NS_ASSUME_NONNULL_BEGIN

/**
 Parses HTTP responses from the Sentry server for rate limits and stores them
 in memory. The server can communicate a rate limit either through the 429
 status code with a "Retry-After" header or through any response with a custom
 "X-Sentry-Rate-Limits" header. This class is thread safe.
*/
NS_SWIFT_NAME(DefaultRateLimits)
@interface SentryDefaultRateLimits : SENTRY_BASE_OBJECT <SentryRateLimits>

- (instancetype)initWithRetryAfterHeaderParser:
                    (SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                            andRateLimitParser:(SentryRateLimitParser *)rateLimitParser;

@end

NS_ASSUME_NONNULL_END
