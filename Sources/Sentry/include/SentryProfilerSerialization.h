#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryEnvelopeItem;
@class SentryHub;
@class SentryId;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN SentryEnvelopeItem *_Nullable sentry_profileEnvelopeItem(
    SentryTransaction *transaction, NSDate *startTimestamp);

/** Alternative affordance for use by PrivateSentrySDKOnly for hybrid SDKs. */
NSMutableDictionary<NSString *, id> *_Nullable sentry_collectProfileData(
    uint64_t startSystemTime, uint64_t endSystemTime, SentryId *traceId, SentryHub *hub);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
