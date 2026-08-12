#if __has_include(<Sentry/SentryEvent.h>)
#    import <Sentry/SentryEvent.h>
#    import <Sentry/SentrySpanProtocol.h>
#else
#    import "SentryEvent.h"
#    import "SentrySpanProtocol.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT
#if !SENTRY_TEST && !SENTRY_TEST_CI
- (instancetype)initWithLevel:(SentryLevel)level NS_UNAVAILABLE;
- (instancetype)initWithError:(NSError *)error NS_UNAVAILABLE;
#endif // !SENTRY_TEST && !SENTRY_TEST_CI

/// The child spans belonging to this transaction.
@property (nonatomic, strong) NSArray<id<SentrySpan>> *spans;

@end

NS_ASSUME_NONNULL_END
