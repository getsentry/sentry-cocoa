#if __has_include(<Sentry/SentryDsn.h>)
#    import <Sentry/SentryDsn.h>
#else
#    import "SentryDsn.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn (Private)

- (NSString *)getHash;

@end

NS_ASSUME_NONNULL_END
