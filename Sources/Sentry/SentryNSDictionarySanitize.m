#import "SentryNSDictionarySanitize.h"
#import "SentryArray.h"
#import "SentryDateUtils.h"

static const NSUInteger kMaxSanitizeDepth = 200;

NSDictionary *_Nullable sentry_sanitize_with_depth(
    NSDictionary *_Nullable dictionary, NSUInteger depth);
NSArray *sentry_sanitizeArray_with_depth(NSArray *array, NSUInteger depth);

NSDictionary *_Nullable sentry_sanitize_with_depth(
    NSDictionary *_Nullable dictionary, NSUInteger depth)
{
    if (dictionary == nil) {
        return nil;
    }

    if (![[dictionary class] isSubclassOfClass:[NSDictionary class]]) {
        return nil;
    }

    if (depth >= kMaxSanitizeDepth) {
        return nil;
    }

    // Defensive copy to prevent mutation during enumeration.
    NSDictionary *dictionaryCopy = [dictionary copy];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (id rawKey in dictionaryCopy.allKeys) {
        id rawValue = [dictionaryCopy objectForKey:rawKey];

        NSString *stringKey;
        if ([rawKey isKindOfClass:NSString.class]) {
            stringKey = rawKey;
        } else {
            stringKey = [rawKey description];
        }

        if ([stringKey hasPrefix:@"__sentry"]) {
            continue; // We don't want to add __sentry variables
        }

        if ([rawValue isKindOfClass:NSString.class]) {
            [dict setValue:rawValue forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [dict setValue:rawValue forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            NSDictionary *innerDict = (NSDictionary *)rawValue;
            [dict setValue:sentry_sanitize_with_depth(innerDict, depth + 1) forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [dict setValue:sentry_sanitizeArray_with_depth(rawValue, depth + 1) forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [dict setValue:sentry_toIso8601String(date) forKey:stringKey];
        } else {
            [dict setValue:[rawValue description] forKey:stringKey];
        }
    }
    return dict;
}

NSDictionary *_Nullable sentry_sanitize(NSDictionary *_Nullable dictionary)
{
    return sentry_sanitize_with_depth(dictionary, 0);
}
