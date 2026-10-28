#import "SentryProfilerConfigurationBridge.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentrySwift.h"

SentryProfilingConfiguration
sentry_profilerConfigurationSnapshot(void)
{
    SentryProfileConfiguration *configuration = sentry_getProfileConfiguration();
    SentryProfileOptions *options = configuration.profileOptions;
    return (SentryProfilingConfiguration) { configuration != nil
            && (options == nil
                || (options.profileAppStarts && options.lifecycle == SentryProfileLifecycleTrace)),
        configuration.isProfilingThisLaunch && options != nil
            && options.lifecycle == SentryProfileLifecycleTrace };
}

static SentryProfilingTraceDecision
continuousTraceDecision(SentryProfileOptions *options, SentryTransactionContext *transactionContext)
{
    if (options.lifecycle != SentryProfileLifecycleTrace
        || transactionContext.sampled != kSentrySampleDecisionYes) {
        return SentryProfilingTraceDecisionNone;
    }
    SentrySamplerDecision *decision
        = sentry_getProfileConfiguration().profilerSessionSampleDecision;
    if (decision == nil || decision.decision != kSentrySampleDecisionYes) {
        return SentryProfilingTraceDecisionNone;
    }
    return SentryProfilingTraceDecisionContinuous;
}

SentryProfilingTraceDecision
sentry_profilerTraceDecision(SentryTracerConfiguration *configuration,
    SentryHubInternal *_Nullable hub, SentryTransactionContext *transactionContext)
{
    SentryProfileConfiguration *profileConfiguration = sentry_getProfileConfiguration();
    if (profileConfiguration.profileOptions != nil) {
        return continuousTraceDecision(
            SENTRY_UNWRAP_NULLABLE(SentryProfileOptions, profileConfiguration.profileOptions),
            transactionContext);
    }

    SentryClientInternal *client = hub.getClient;
    if (client != nil && [client.options isContinuousProfilingEnabled]) {
        if (transactionContext.parentSpanId != nil) {
            SENTRY_LOG_DEBUG(@"Not a root span, will not start automatically for trace lifecycle.");
            return SentryProfilingTraceDecisionNone;
        }
        SentryProfileOptions *options = client.options.profiling;
        if (options == nil) {
            SENTRY_LOG_DEBUG(@"No profiling options found, will not start profiler.");
            return SentryProfilingTraceDecisionNone;
        }
        return continuousTraceDecision(options, transactionContext);
    }

    SentrySamplerDecision *decision = configuration.profilesSamplerDecision;
    BOOL profileShouldBeSampled = decision != nil && decision.decision == kSentrySampleDecisionYes;
    return SentryProfilerSDKAdapter.shared.isTracingAppLaunch || profileShouldBeSampled
        ? SentryProfilingTraceDecisionTransaction
        : SentryProfilingTraceDecisionNone;
}

BOOL
sentry_profilerUsesTraceLifecycle(SentryClientInternal *_Nullable client)
{
    return client != nil && [client.options isContinuousProfilingEnabled] &&
        [client.options isProfilingCorrelatedToTraces];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
