#import "SentryProfilingSwiftHelpers.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryId+Private.h"
#    import "SentrySwift.h"

SentryProfilingId *
sentry_profilingIdFromSentryId(SentryId *sentryID)
{
    return [[SentryProfilingId alloc] initWithUUID:sentryID.uuid];
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
