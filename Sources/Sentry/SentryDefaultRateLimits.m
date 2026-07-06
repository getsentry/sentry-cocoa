#import "SentryDefaultRateLimits.h"
#import "SentryConcurrentRateLimitsDictionary.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDateUtil.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Reads a header from the response case-insensitively.
 *
 * Since HTTP/2, HTTP field names are case-insensitive, including HTTP headers; see HTTP/2 (RFC
 * 9113, 8.2.1) and HTTP/3 (RFC 9114, 4.2):
 * - https://www.rfc-editor.org/rfc/rfc9113#section-8.2.1
 * - https://www.rfc-editor.org/rfc/rfc9114#section-4.2
 *
 * On iOS 13, macOS 10.15, tvOS 13, watchOS 6 and above we use
 * @c -[NSHTTPURLResponse valueForHTTPHeaderField:], which reads headers case-insensitively. On
 * lower deployment targets that API isn't available, so we fall back to scanning @c
 * allHeaderFields: its subscripting is case-sensitive, so we compare all keys case-insensitively
 * against @c name. This is O(n), which is acceptable for the small number of response headers.
 */
static NSString *_Nullable sentryCaseInsensitiveHeaderValue(
    NSHTTPURLResponse *response, NSString *name)
{
    if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)) {
        return [response valueForHTTPHeaderField:name];
    }

    NSString *lowercasedName = name.lowercaseString;
    for (id key in response.allHeaderFields) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *headerName = (NSString *)key;
        if (![headerName.lowercaseString isEqualToString:lowercasedName]) {
            continue;
        }

        id value = response.allHeaderFields[headerName];
        if (![value isKindOfClass:[NSString class]]) {
            return nil;
        }
        return (NSString *)value;
    }
    return nil;
}

@interface SentryDefaultRateLimits ()

@property (nonatomic, strong) SentryConcurrentRateLimitsDictionary *rateLimits;
@property (nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property (nonatomic, strong) SentryRateLimitParser *rateLimitParser;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (nonatomic, strong) SentryDateUtil *dateUtil;

@end

@implementation SentryDefaultRateLimits

- (instancetype)initWithRetryAfterHeaderParser:
                    (SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                            andRateLimitParser:(SentryRateLimitParser *)rateLimitParser
                           currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.rateLimits = [[SentryConcurrentRateLimitsDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
        self.currentDateProvider = currentDateProvider;
        self.dateUtil = [[SentryDateUtil alloc] initWithCurrentDateProvider:currentDateProvider];
    }
    return self;
}

- (BOOL)isRateLimitActive:(SentryDataCategory)category
{
    NSDate *_Nullable categoryDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *_Nullable allCategoriesDate =
        [self.rateLimits getRateLimitForCategory:kSentryDataCategoryAll];

    BOOL isActiveForCategory = [self.dateUtil isInFuture:categoryDate];
    BOOL isActiveForCategories = [self.dateUtil isInFuture:allCategoriesDate];

    if (isActiveForCategory || isActiveForCategories) {
        return YES;
    } else {
        return NO;
    }
}

- (void)update:(NSHTTPURLResponse *)response
{
    NSString *rateLimitsHeader
        = sentryCaseInsensitiveHeaderValue(response, @"x-sentry-rate-limits");
    if (nil != rateLimitsHeader) {
        NSDictionary<NSNumber *, NSDate *> *limits = [self.rateLimitParser parse:rateLimitsHeader];

        for (NSNumber *categoryAsNumber in limits.allKeys) {
            SentryDataCategory category
                = sentryDataCategoryForNSUInteger(categoryAsNumber.unsignedIntegerValue);

            [self updateRateLimit:category
                         withDate:SENTRY_UNWRAP_NULLABLE(NSDate, limits[categoryAsNumber])];
        }
    } else if (response.statusCode == 429) {
        NSDate *retryAfterHeaderDate = [self.retryAfterHeaderParser
            parse:sentryCaseInsensitiveHeaderValue(response, @"retry-after")];

        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [self.currentDateProvider.date dateByAddingTimeInterval:60];
        }

        [self updateRateLimit:kSentryDataCategoryAll withDate:retryAfterHeaderDate];
    }
}

- (void)updateRateLimit:(SentryDataCategory)category withDate:(NSDate *)newDate
{
    NSDate *existingDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *longerRateLimitDate = [SentryDateUtil getMaximumDate:existingDate andOther:newDate];
    [self.rateLimits addRateLimit:category validUntil:longerRateLimitDate];
}

@end

NS_ASSUME_NONNULL_END
