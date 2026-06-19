#if __has_include(<Sentry/SentryBreadcrumb.h>)
#    import <Sentry/SentryBreadcrumb.h>
#else
#    import "SentryBreadcrumb.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryBreadcrumb ()

/**
 * Initializes a SentryBreadcrumb from a JSON object.
 * @param dictionary The dictionary containing breadcrumb data.
 * @return The SentryBreadcrumb.
 */
- (instancetype _Nonnull)initWithDictionary:(NSDictionary *_Nonnull)dictionary;

/**
 * Returns a snapshot copy with its own strong references to all property values.
 * The copy is independent of the original: deallocating either one does not
 * affect the other's ivars.
 */
- (SentryBreadcrumb *_Nonnull)snapshotCopy;
@end

NS_ASSUME_NONNULL_END
