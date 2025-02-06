#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"

@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryHub;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN void sentry_captureTransactionWithProfile(SentryHub *hub,
    SentryDispatchQueueWrapper *dispatchQueue, SentryTransaction *transaction,
    NSDate *startTimestamp);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
