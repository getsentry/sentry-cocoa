#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;
@class SentrySamplerDecision;
@class SentrySamplingContext;

/**
 * Determines whether a trace should be sampled based on the context and options.
 */
SentrySamplerDecision *sampleTrace(SentrySamplingContext *context, SentryOptions *options);

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Determines whether a profile should be sampled based on the context, options, and
 * whether the trace corresponding to the profile was sampled.
 */
SentrySamplerDecision *sampleProfile(SentrySamplingContext *context,
    SentrySamplerDecision *tracesSamplerDecision, SentryOptions *options);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
