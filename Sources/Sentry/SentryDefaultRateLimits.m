#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryHttpDateParser.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN
/*
 * This code was moved from SentryHttpTransport and needs to be updated.
 */
@interface SentryDefaultRateLimits ()

@property(nonatomic, strong) NSDictionary<NSString *, NSDate *> *rateLimits;
@property(nonatomic, strong) SentryHttpDateParser *httpDateParser;

/**
 * datetime until we keep radio silence. Populated when response has HTTP 429
 * and "Retry-After" header -> rate limit exceeded.
 */
@property(atomic, strong) NSDate *_Nullable radioSilenceDeadline;

@end

@implementation SentryDefaultRateLimits

- (instancetype)init
{
    if (self = [super init]) {
        self.rateLimits = [[NSDictionary alloc] init];
        self.httpDateParser = [[SentryHttpDateParser alloc] init];
    }
    return self;
}

- (BOOL)isRateLimitReached:(NSString *)type {
    if (nil == self.radioSilenceDeadline) {
        return NO;
    }

    NSDate *now = [SentryCurrentDate date];
    NSComparisonResult result = [now compare:[self radioSilenceDeadline]];

    if (result == NSOrderedAscending) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Rate limit reached until: %@",  self.radioSilenceDeadline] andLevel:kSentryLogLevelError];
        return YES;
    } else {
        self.radioSilenceDeadline = nil;
        return NO;
    }
}

/**
 * When rate limit has been exceeded we updates the radio silence deadline and
 * therefor activates radio silence for at least
 * 60 seconds (default, see `defaultRadioSilenceDeadline`).
 */
- (void)update:(NSHTTPURLResponse *)response {
    self.radioSilenceDeadline = [self parseRetryAfterHeader:response.allHeaderFields[@"Retry-After"]];
}

/**
 * used if actual time/deadline couldn't be determined.
 */
- (NSDate *)defaultRadioSilenceDeadline {
    return [[SentryCurrentDate date] dateByAddingTimeInterval:60];
}

/**
 * parses value of HTTP Header "Retry-After" which in most cases is sent in
 * combination with HTTP status 429 Too Many Requests.
 *
 * Retry-After value is a time-delta in seconds or a date.
 * In every case this method computes the date aka. `radioSilenceDeadline`.
 *
 * See RFC2616 for details on "Retry-After".
 * https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.37
 *
 * @return NSDate representation of Retry-After.
 *         As fallback `defaultRadioSilenceDeadline` is returned if parsing was
 *         unsuccessful.
 */
- (NSDate *)parseRetryAfterHeader:(NSString * __nullable)retryAfterHeader {
    if (nil == retryAfterHeader || 0 == [retryAfterHeader length]) {
        return [self defaultRadioSilenceDeadline];
    }

    NSDate *now = [SentryCurrentDate date];

    // try to parse as double/seconds
    double retryAfterSeconds = [retryAfterHeader doubleValue];
    NSLog(@"parseRetryAfterHeader string '%@' to double: %f", retryAfterHeader, retryAfterSeconds);
    if (0 != retryAfterSeconds) {
        return [now dateByAddingTimeInterval:retryAfterSeconds];
    }

    // parsing as double/seconds failed, try to parse as date
    NSDate *retryAfterDate = [self.httpDateParser dateFromString:retryAfterHeader];

    if (nil == retryAfterDate) {
        // parsing as seconds and date failed
        return [self defaultRadioSilenceDeadline];
    }
    return retryAfterDate;
}

@end

NS_ASSUME_NONNULL_END
