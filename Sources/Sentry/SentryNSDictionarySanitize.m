#import "SentryNSDictionarySanitize.h"
#import "SentryArray.h"
#import "SentryDateUtils.h"

NSDictionary *_Nullable sentry_sanitize(NSDictionary *_Nullable dictionary)
{
    if (dictionary == nil) {
        return nil;
    }

    if (![[dictionary class] isSubclassOfClass:[NSDictionary class]]) {
        return nil;
    }

    // Defensive copy: if the caller passed an NSMutableDictionary, iterating it while
    // another thread mutates it causes a crash. [NSDictionary copy] returns self (no-op),
    // while [NSMutableDictionary copy] creates an immutable snapshot.
    NSDictionary *safeDictionary = [dictionary copy];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (id rawKey in safeDictionary.allKeys) {
        id rawValue = [safeDictionary objectForKey:rawKey];

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
            [dict setValue:sentry_sanitize(innerDict) forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [dict setValue:[SentryArray sanitizeArray:rawValue] forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [dict setValue:sentry_toIso8601String(date) forKey:stringKey];
        } else {
            [dict setValue:[rawValue description] forKey:stringKey];
        }
    }
    return dict;
}
