#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"

NS_ASSUME_NONNULL_BEGIN
@interface SentryDefaultRateLimits ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *rateLimits;
@property(atomic, strong) NSDate *_Nullable retryAfterHeaderDate;
@property(nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property(nonatomic, strong) SentryRateLimitParser *rateLimitParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype) initWithParsers:(SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                 rateLimitParser:(SentryRateLimitParser *)rateLimitParser{
    if (self = [super init]) {
        self.rateLimits = [[NSMutableDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
    }
    return self;
}

- (BOOL)isRateLimitActive:(NSString *)type {
    return [self isCustomHeaderRateLimitActive:type] || [self isRetryAfterHeaderLimitActive];
}

- (BOOL)isCustomHeaderRateLimitActive:(NSString *)type {
    NSDate *rateLimitDate = self.rateLimits[type];
    BOOL isActive = [self isInFuture: rateLimitDate];
    if (isActive) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"X-Sentry-Rate-Limits reached until: %@",  rateLimitDate] andLevel:kSentryLogLevelError];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isRetryAfterHeaderLimitActive {
    if (nil == self.retryAfterHeaderDate) {
        return NO;
    }
    
    BOOL isActive = [self isInFuture:self.retryAfterHeaderDate];
    if (isActive) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Retry-After limit reached until: %@",  self.retryAfterHeaderDate] andLevel:kSentryLogLevelError];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isInFuture:(NSDate *)date {
    NSComparisonResult result = [[SentryCurrentDate date] compare:date];
    if (result == NSOrderedAscending) {
        return YES;
    }
    
    return NO;
}

- (void)update:(NSHTTPURLResponse *)response {
    if (response.statusCode == 429) {
        NSDate* retryAfterHeaderDate = [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];
        
        self.retryAfterHeaderDate = retryAfterHeaderDate;
    }
    
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    NSDictionary<NSString *, NSDate *> * limits = [self.rateLimitParser parse:rateLimitsHeader];
    [self.rateLimits addEntriesFromDictionary:limits];
}

@end

NS_ASSUME_NONNULL_END
