#import "SentryArray.h"
#import "SentryDateUtils.h"
#import "SentryInternalDefines.h"
#import "SentryNSDictionarySanitize.h"

static const NSUInteger kMaxSanitizeDepth = 200;

extern NSDictionary *_Nullable sentry_sanitize_with_depth(
    NSDictionary *_Nullable dictionary, NSUInteger depth);
extern NSArray *sentry_sanitizeArray_with_depth(NSArray *array, NSUInteger depth);

@implementation SentryArray

+ (NSArray *)sanitizeArray:(NSArray *)array
{
    return sentry_sanitizeArray_with_depth(array, 0);
}

@end

NSArray *
sentry_sanitizeArray_with_depth(NSArray *array, NSUInteger depth)
{
    if (depth >= kMaxSanitizeDepth) {
        return @[];
    }

    // Defensive copy to prevent mutation during enumeration.
    NSArray *arrayCopy = [array copy];

    NSMutableArray *result = [NSMutableArray array];
    for (id rawValue in arrayCopy) {
        if ([rawValue isKindOfClass:NSString.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            NSDictionary *_Nullable sanitizedDict
                = sentry_sanitize_with_depth((NSDictionary *)rawValue, depth + 1);
            if (sanitizedDict == nil) {
                // Adding `nil` to an array is not allowed in Objective-C and raises an
                // `NSInvalidArgumentException`.
                continue;
            }
            [result addObject:SENTRY_UNWRAP_NULLABLE(NSDictionary, sanitizedDict)];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [result addObject:sentry_sanitizeArray_with_depth(rawValue, depth + 1)];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [result addObject:sentry_toIso8601String(date)];
        } else {
            [result addObject:[rawValue description]];
        }
    }
    return result;
}
