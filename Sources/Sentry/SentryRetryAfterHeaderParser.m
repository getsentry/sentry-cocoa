#import <Foundation/Foundation.h>
#import "SentryRetryAfterHeaderParser.h"
#import "SentryCurrentDate.h"
#import "SentryHttpDateParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRetryAfterHeaderParser ()

@property(nonatomic, strong) SentryHttpDateParser *httpDateParser;

@end

@implementation SentryRetryAfterHeaderParser

- (instancetype)initWithHttpDateParser:(SentryHttpDateParser *)httpDateParser {
    if (self = [super init]) {
        self.httpDateParser = httpDateParser;
    }
    return self;
}

- (NSDate *_Nonnull)parse:(NSString *_Nullable)retryAfterHeader {
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
