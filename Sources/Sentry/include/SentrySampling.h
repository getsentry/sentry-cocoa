#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptionsInternal;
@class SentrySamplerDecision;
@class SentrySamplingContext;

/**
 * Determines whether a trace should be sampled based on the context and options.
 */
SENTRY_EXTERN SentrySamplerDecision *sentry_sampleTrace(
    SentrySamplingContext *context, SentryOptionsInternal *_Nullable options);

#if SENTRY_TARGET_PROFILING_SUPPORTED
SENTRY_EXTERN SentrySamplerDecision *sentry_sampleProfileSession(float sessionSampleRate);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
