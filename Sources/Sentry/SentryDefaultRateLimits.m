#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"

NS_ASSUME_NONNULL_BEGIN
@interface SentryDefaultRateLimits ()

/* Key is the type and value is valid until date */
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *rateLimits;
@property(nonatomic, strong) NSDate *_Nullable retryAfterHeaderDate;

@property(nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property(nonatomic, strong) SentryRateLimitParser *rateLimitParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype) initWithRetryAfterHeaderParser:(SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                 andRateLimitParser:(SentryRateLimitParser *)rateLimitParser{
    if (self = [super init]) {
        self.rateLimits = [[NSMutableDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
    }
    return self;
}

- (BOOL)isRateLimitActive:(NSString *)type {
    @synchronized (self) {
        return [self isCustomHeaderRateLimitActive:type] ||
        [self isRetryAfterHeaderLimitActive];
    }
}

- (BOOL)isCustomHeaderRateLimitActive:(NSString *)type {
    NSDate *rateLimitDate = self.rateLimits[type];
    BOOL isActive = [self isInFuture: rateLimitDate];
    if (isActive) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"X-Sentry-Rate-Limits reached until: %@",  rateLimitDate] andLevel:kSentryLogLevelDebug];
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
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Retry-After limit reached until: %@",  self.retryAfterHeaderDate] andLevel:kSentryLogLevelDebug];
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
    NSDate* retryAfterHeaderDate = nil;
    if (response.statusCode == 429) {
        retryAfterHeaderDate = [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];
        
        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [[SentryCurrentDate date] dateByAddingTimeInterval:60];
        }
    }
    
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    NSDictionary<NSString *, NSDate *> * limits = [self.rateLimitParser parse:rateLimitsHeader];
    
    // Keep the sync block as small as possible
    @synchronized (self) {
        if (nil != retryAfterHeaderDate) {
            self.retryAfterHeaderDate = retryAfterHeaderDate;
        }
        
        [self.rateLimits addEntriesFromDictionary:limits];
    }
}

@end

NS_ASSUME_NONNULL_END
