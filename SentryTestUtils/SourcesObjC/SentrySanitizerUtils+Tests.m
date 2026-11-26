#import "SentrySanitizerUtils.h"

NSDictionary *_Nullable sentry_sanitize_with_nsnull(void)
{
    // Cast [NSNull null] to NSDictionary to avoid compiler warnings/errors
    return sentry_sanitize_dictionary((NSDictionary *)[NSNull null]);
}

NSDictionary *_Nullable sentry_sanitize_with_non_dictionary(void)
{
    // Cast @"non-dictionary" to NSDictionary to avoid compiler warnings/errors
    return sentry_sanitize_dictionary((NSDictionary *)@"non-dictionary");
}
