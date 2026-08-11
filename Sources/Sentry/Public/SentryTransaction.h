#if __has_include(<Sentry/SentryEvent.h>)
#    import <Sentry/SentryEvent.h>
#    import <Sentry/SentrySpanProtocol.h>
#else
#    import "SentryEvent.h"
#    import "SentrySpanProtocol.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT
- (instancetype)initWithLevel:(SentryLevel)level NS_UNAVAILABLE;
- (instancetype)initWithError:(NSError *)error NS_UNAVAILABLE;

@property (nonatomic, strong) SentryTracer *trace;
@property (nonatomic, copy, nullable) NSArray<NSString *> *viewNames;
@property (nonatomic, strong) NSArray<id<SentrySpan>> *spans;

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<id<SentrySpan>> *)children;

@end

NS_ASSUME_NONNULL_END
