#import "NSArray+SentrySanitize.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"

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
            [result addObject:[(NSDictionary *)rawValue sentry_sanitize]];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [result addObject:[SentryArray sanitizeArray:rawValue]];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            [result addObject:[(NSDate *)rawValue sentry_toIso8601String]];
        } else {
            [result addObject:[rawValue description]];
        }
    }
    return result;
}

@end
