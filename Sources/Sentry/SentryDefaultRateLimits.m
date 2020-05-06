#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"
#import "SentryConcurrentRateLimitsDictionary.h"
#import "SentryRateLimitCategoryMapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultRateLimits ()

/* Key is the type and value is valid until date */
@property(nonatomic, strong) SentryConcurrentRateLimitsDictionary *rateLimits;

@property(nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property(nonatomic, strong) SentryRateLimitParser *rateLimitParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype) initWithRetryAfterHeaderParser:(SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                 andRateLimitParser:(SentryRateLimitParser *)rateLimitParser {
    if (self = [super init]) {
        self.rateLimits = [[SentryConcurrentRateLimitsDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
    }
    return self;
}

- (BOOL)isRateLimitActive:(SentryRateLimitCategory)category {
    NSDate *categoryDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *allCategoriesDate = [self.rateLimits getRateLimitForCategory:kSentryRateLimitCategoryAll];
    
    BOOL isActiveForCategory = [self isInFuture:categoryDate];
    BOOL isActiveForCategories = [self isInFuture:allCategoriesDate];
    
    if (isActiveForCategory || isActiveForCategories) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isInFuture:(NSDate *)date {
    NSComparisonResult result = [[SentryCurrentDate date] compare:date];
    return result == NSOrderedAscending;
}

- (void)update:(NSHTTPURLResponse *)response {
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    if (nil != rateLimitsHeader) {
        NSDictionary<NSNumber *, NSDate *> * limits = [self.rateLimitParser parse:rateLimitsHeader];
        
        [self.rateLimits addRateLimits:limits];
    } else if (response.statusCode == 429) {
        NSDate* retryAfterHeaderDate = [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];
        
        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [[SentryCurrentDate date] dateByAddingTimeInterval:60];
        }
        
        [self.rateLimits addRateLimits:@{[NSNumber numberWithInt:kSentryRateLimitCategoryAll] : retryAfterHeaderDate}];
    }
}

@end

NS_ASSUME_NONNULL_END
