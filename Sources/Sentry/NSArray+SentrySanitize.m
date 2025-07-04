#import "NSArray+SentrySanitize.h"
#import "SentryDateUtils.h"
#import "SentryNSDictionarySanitize.h"

@implementation SentryArray

+ (NSArray *)sanitizeArray:(NSArray *)array;
{
    NSMutableArray *result = [NSMutableArray array];
    for (id rawValue in array) {
        if ([rawValue isKindOfClass:NSString.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            NSDictionary *sanitized = sentry_sanitize((NSDictionary *)rawValue);
            if (sanitized != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
                [result addObject:sanitized];
#pragma clang diagnostic pop
            }
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [result addObject:[SentryArray sanitizeArray:rawValue]];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [result addObject:sentry_toIso8601String(date)];
        } else {
            [result addObject:[rawValue description]];
        }
    }
    return result;
}

@end
