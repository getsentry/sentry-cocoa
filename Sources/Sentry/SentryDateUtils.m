#import "SentryDateUtils.h"

NS_ASSUME_NONNULL_BEGIN

NSDateFormatter *
sentryGetIso8601Formatter(void)
{
    static NSDateFormatter *isoFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [NSDateFormatter new];
        [isoFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    });

    return isoFormatter;
}

/**
 * The NSDateFormatter only works with milliseconds resolution, even though NSDate has a higher
 * precision. For more information checkout
 * https://stackoverflow.com/questions/23684727/nsdateformatter-milliseconds-bug/23685280#23685280.
 * The SDK can either send timestamps to Sentry a string as defined in RFC 3339 or a numeric
 * (integer or float) value representing the number of seconds that have elapsed since the Unix
 * epoch, see https://develop.sentry.dev/sdk/event-payloads/. Instead of appending micro and
 * nanoseconds to the output of NSDateFormatter please use a numeric float instead, which can be
 * retrieved with timeIntervalSince1970.
 */
NSDateFormatter *
sentryGetIso8601FormatterWithMillisecondPrecision(void)
{
    static NSDateFormatter *isoFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [NSDateFormatter new];
        [isoFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    });

    return isoFormatter;
}

NSDate *_Nullable sentry_fromIso8601String(NSString *string)
{
    NSDate *date = [sentryGetIso8601FormatterWithMillisecondPrecision() dateFromString:string];
    if (nil == date) {
        // Parse date with low precision formatter for backward compatible
        return [sentryGetIso8601Formatter() dateFromString:string];
    } else {
        return date;
    }
}

/**
 * Only works with milliseconds precision. For more details see
 * getIso8601FormatterWithMillisecondPrecision.
 */
NSString *
sentry_toIso8601String(NSDate *date)
{
    NSDateFormatter *formatter = sentryGetIso8601FormatterWithMillisecondPrecision();
    return [formatter stringFromDate:date];
}

NS_ASSUME_NONNULL_END
