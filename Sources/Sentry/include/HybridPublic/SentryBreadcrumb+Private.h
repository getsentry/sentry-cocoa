#if __has_include(<Sentry/SentryBreadcrumb.h>)
#    import <Sentry/SentryBreadcrumb.h>
#else
#    import "SentryBreadcrumb.h"
#endif

@interface SentryBreadcrumb ()

/**
 * Origin of the breadcrumb that is used to identify source of the breadcrumb
 * For example hybrid SDKs can identify native breadcrumbs from JS or Flutter
 */
@property (nonatomic, copy, nullable) NSString *origin;

/**
 * Initializes a SentryBreadcrumb from a JSON object.
 * @param dictionary The dictionary containing breadcrumb data.
 * @return The SentryBreadcrumb.
 */
- (instancetype _Nonnull)initWithDictionary:(NSDictionary *_Nonnull)dictionary;
@end
