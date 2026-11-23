#import "SentryProfilingSwiftHelpers.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentrySwift.h"

NSString *
sentry_stringFromSentryID(SentryId *sentryID)
{
    return sentryID.sentryIdString;
}

SentryId *
sentry_getSentryId(void)
{
    return [[SentryId alloc] init];
}

SentryId *
sentry_getTraceID(SentryTransactionContext *context)
{
    return context.traceId;
}

void
sentry_startLaunchProfile(void)
{
    [SentryLaunchProfiling startLaunchProfile];
}

SentryTracer *_Nullable sentry_tracerForTransaction(id transaction)
{
    return (SentryTracer *)[(SentryTransaction *)transaction trace];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
