#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryHttpDateParser.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"


NS_ASSUME_NONNULL_BEGIN
@interface SentryDefaultRateLimits ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *rateLimits;
@property(atomic, strong) NSDate *_Nullable retryAfterHeaderDate;
@property(nonatomic, strong) SentryHttpDateParser *httpDateParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype)init
{
    if (self = [super init]) {
        self.rateLimits = [[NSMutableDictionary alloc] init];
        self.httpDateParser = [[SentryHttpDateParser alloc] init];
    }
    return self;
}

//TODO remove rate limit from naming because is also retry header
- (BOOL)isRateLimitReached:(NSString *)type {
    NSDate *rateLimitDate = self.rateLimits[type];
    BOOL isRateLimit = [self isExpired: rateLimitDate];
    if (isRateLimit) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Rate limit reached until: %@",  rateLimitDate] andLevel:kSentryLogLevelError];
        return YES;
    }
    
    if (nil != self.retryAfterHeaderDate) {
         BOOL isRetryAfterLimit = [self isExpired:self.retryAfterHeaderDate];
        
        if (isRetryAfterLimit) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Retry After reached until: %@",  self.retryAfterHeaderDate] andLevel:kSentryLogLevelError];
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isExpired:(NSDate *)date {
    NSDate *now = [SentryCurrentDate date];
    NSComparisonResult result = [now compare:date];

    if (result == NSOrderedAscending) {
        return YES;
    }
    
    return NO;
}

- (void)update:(NSHTTPURLResponse *)response {
    
    if (response.statusCode == 429) {
        NSDate* retryAfterHeaderDate = [self parseRetryAfterHeader:response.allHeaderFields[@"Retry-After"]];
        
        self.retryAfterHeaderDate = retryAfterHeaderDate;
    }
    
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    NSDictionary<NSString *, NSDate *> * limits = [SentryRateLimitParser parse:rateLimitsHeader];
    [self.rateLimits addEntriesFromDictionary:limits];
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
        return [self defaultRetryAfterValue];
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
        return [self defaultRetryAfterValue];
    }
    return retryAfterDate;
}

- (NSDate *)defaultRetryAfterValue {
    return [[SentryCurrentDate date] dateByAddingTimeInterval:60];
}

@end

NS_ASSUME_NONNULL_END
