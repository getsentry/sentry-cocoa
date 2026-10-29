#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryHub+Private.h"
#    if SWIFT_PACKAGE
#        import "SentrySwift.h"
#    else
@import Sentry;
#    endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilerDeliveryTestHub : SentryHubInternal
@property (nonatomic) NSUInteger transactionCount;
@property (nonatomic) NSUInteger envelopeCount;
@property (nonatomic, strong, nullable) SentryTransaction *lastTransaction;
@property (nonatomic, strong, nullable) SentryScope *lastScope;
@property (nonatomic, strong, nullable) SentryEnvelope *lastEnvelope;
@end

NS_ASSUME_NONNULL_END
#endif
