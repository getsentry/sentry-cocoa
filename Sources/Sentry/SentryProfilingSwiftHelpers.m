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

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
