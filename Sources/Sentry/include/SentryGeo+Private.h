#if __has_include(<Sentry/SentryGeo.h>)
#    import <Sentry/SentryGeo.h>
#else
#    import "SentryGeo.h"
#endif

@interface SentryGeo ()

/**
 * Initializes a SentryGeo from a dictionary.
 * @param dictionary The dictionary containing geo data.
 * @return The SentryGeo.
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
