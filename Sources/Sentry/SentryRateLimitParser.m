#import "SentryRateLimitParser.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDateUtil.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRateLimitParser ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;

@end

@implementation SentryRateLimitParser

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.currentDateProvider = currentDateProvider;
    }
    return self;
}

- (NSDictionary<NSNumber *, NSDate *> *)parse:(NSString *)header
{
    if ([header length] == 0) {
        return @{};
    }

    NSMutableDictionary<NSNumber *, NSDate *> *rateLimits = [NSMutableDictionary new];

    // The header might contain whitespaces and they must be ignored.
    NSString *headerNoWhitespaces = [self removeAllWhitespaces:header];

    // Each quotaLimit exists of retryAfter:categories:scope. The scope is
    // ignored here as it can be ignored by SDKs.
    for (NSString *quota in [headerNoWhitespaces componentsSeparatedByString:@","]) {
        NSArray<NSString *> *parameters = [quota componentsSeparatedByString:@":"];

        NSNumber *rateLimitInSeconds = [self parseRateLimitSeconds:parameters[0]];
        if (nil == rateLimitInSeconds || [rateLimitInSeconds intValue] <= 0) {
            continue;
        }

        for (NSNumber *category in [self parseCategories:parameters[1]]) {
            SentryDataCategory dataCategory
                = sentryDataCategoryForNSUInteger(category.integerValue);

            // Namespaces should only be available for MetricBucket
            if (dataCategory == kSentryDataCategoryMetricBucket && parameters.count > 4) {
                NSString *namespacesAsString = parameters[4];

                NSArray<NSString *> *namespaces =
                    [namespacesAsString componentsSeparatedByString:@";"];
                if (namespacesAsString.length == 0 || [namespaces containsObject:@"custom"]) {
                    rateLimits[category] = [self getLongerRateLimit:rateLimits[category]
                                              andRateLimitInSeconds:rateLimitInSeconds];
                }

            } else {
                rateLimits[category] = [self getLongerRateLimit:rateLimits[category]
                                          andRateLimitInSeconds:rateLimitInSeconds];
            }
        }
    }

    return rateLimits;
}

- (NSString *)removeAllWhitespaces:(NSString *)string
{
    NSArray *words = [string
        componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [words componentsJoinedByString:@""];
}

- (NSNumber *)parseRateLimitSeconds:(NSString *)string
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterNoStyle;
    NSNumber *_Nullable result = [numberFormatter numberFromString:string];
    if (result == nil) {
        return @0; // Default to 0 if parsing fails
    }
    return (NSNumber *_Nonnull)result;
}

- (NSArray<NSNumber *> *)parseCategories:(NSString *)categoriesAsString
{
    // The categories are a semicolon separated list. If this parameter is empty
    // it stands for all categories. componentsSeparatedByString returns one
    // category even if this parameter is empty.
    NSMutableArray<NSNumber *> *categories = [NSMutableArray new];
    for (NSString *categoryAsString in [categoriesAsString componentsSeparatedByString:@";"]) {
        SentryDataCategory category = sentryDataCategoryForString(categoryAsString);

        // Unknown categories must be ignored. UserFeedback is not listed for rate limits, see
        // https://develop.sentry.dev/sdk/rate-limiting/#definitions
        if (category != kSentryDataCategoryUnknown && category != kSentryDataCategoryUserFeedback) {
            [categories addObject:@(category)];
        }
    }

    return categories;
}

- (NSDate *)getLongerRateLimit:(nullable NSDate *)existingRateLimit
         andRateLimitInSeconds:(NSNumber *)newRateLimitInSeconds
{
    NSDate *newDate = [self.currentDateProvider.date
        dateByAddingTimeInterval:[newRateLimitInSeconds doubleValue]];
    NSDate *_Nullable result = [SentryDateUtil getMaximumDate:newDate andOther:existingRateLimit];
    if (result == nil) {
        return newDate; // Default to newDate if getMaximumDate returns nil
    }
    return (NSDate *_Nonnull)result;
}

@end

NS_ASSUME_NONNULL_END
