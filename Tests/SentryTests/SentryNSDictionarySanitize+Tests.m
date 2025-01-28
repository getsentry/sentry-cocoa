#import "SentryNSDictionarySanitize.h"

NSDictionary *_Nullable sentry_sanitize_with_nsnull(void)
{
    // Cast [NSNull null] to NSDictionary to avoid compiler warnings/errors
    return sentry_sanitize((NSDictionary *)[NSNull null]);
}
