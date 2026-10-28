#import "SentryProfilerConfigurationBridge.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryProfileConfiguration.h"
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

void
sentry_configureContinuousProfiling(SentryOptions *options)
{
    if (options.configureProfiling == nil) {
        SENTRY_LOG_DEBUG(@"Continuous profiling V2 configuration not set by SDK consumer, nothing "
                         @"to do here.");
        return;
    }

    SentryProfileOptions *_Nonnull profilingOptions = [[SentryProfileOptions alloc] init];
    options.profiling = profilingOptions;
    options.configureProfiling(profilingOptions);

    if ((profilingOptions.lifecycle == SentryProfileLifecycleTrace) && !options.isTracingEnabled) {
        SENTRY_LOG_WARN(
            @"Tracing must be enabled in order to configure profiling with trace lifecycle.");
        return;
    }

    // if a launch profiler was started, sentry_profileConfiguration will have been set at that time
    // with the hydrated options that were persisted from the previous SDK start, which are used to
    // help determine when/how to stop the launch profile. otherwise, there won't yet be a
    // SentryProfileConfiguration instance, so we'll instantiate one which will be used to access
    // the profile session sample rate henceforth
    if (sentry_getProfileConfiguration() == nil) {
        sentry_setProfileConfiguration(
            [[SentryProfileConfiguration alloc] initWithProfileOptions:profilingOptions]);
    }

    sentry_reevaluateSessionSampleRate();

    SENTRY_LOG_DEBUG(@"Configured profiling options: <%@: {\n  lifecycle: %@\n  sessionSampleRate: "
                     @"%.2f\n  profileAppStarts: %@\n}",
        options.profiling,
        (profilingOptions.lifecycle == SentryProfileLifecycleTrace) ? @"trace" : @"manual",
        profilingOptions.sessionSampleRate, profilingOptions.profileAppStarts ? @"YES" : @"NO");
}

void
sentry_sdkInitProfilerTasks(SentryOptions *options, SentryHubInternal *hub)
{
    // get the configuration options from the last time the launch config was written; it may be
    // different than the new options the SDK was just started with
    SentryProfileConfiguration *configurationFromLaunch = sentry_getProfileConfiguration();

    sentry_configureContinuousProfiling(options);

    [SentryProfilerSDKAdapter.shared dispatchAsync:^{
        if (configurationFromLaunch.isProfilingThisLaunch) {
            BOOL shouldStopAndTransmitLaunchProfile = YES;

            BOOL profileIsContinuousV2 = configurationFromLaunch.profileOptions != nil;
            BOOL v2LifecycleIsManual = profileIsContinuousV2 &&
                [SENTRY_UNWRAP_NULLABLE(
                    SentryProfileOptions, configurationFromLaunch.profileOptions) lifecycle]
                    != SentryProfileLifecycleTrace;

#    if SENTRY_HAS_UIKIT
            BOOL v2LifecycleIsTrace = profileIsContinuousV2 &&
                [SENTRY_UNWRAP_NULLABLE(
                    SentryProfileOptions, configurationFromLaunch.profileOptions) lifecycle]
                    == SentryProfileLifecycleTrace;
            BOOL profileIsCorrelatedToTrace = !profileIsContinuousV2 || v2LifecycleIsTrace;
            if (profileIsCorrelatedToTrace && configurationFromLaunch.waitForFullDisplay) {
                SENTRY_LOG_DEBUG(
                    @"Will wait to stop launch profile correlated to a trace until full "
                    @"display reported.");
                shouldStopAndTransmitLaunchProfile = NO;
            }
#    endif // SENTRY_HAS_UIKIT

            if (v2LifecycleIsManual) {
                SENTRY_LOG_DEBUG(@"Continuous manual launch profiles aren't stopped on calls to "
                                 @"SentrySDK.start, "
                                 @"not stopping profile.");
                shouldStopAndTransmitLaunchProfile = NO;
            }

            if (shouldStopAndTransmitLaunchProfile) {
                SENTRY_LOG_DEBUG(
                    @"Stopping launch profile in SentrySDK.start because there is no time "
                    @"to display tracker to stop it.");
                [SentryLaunchProfiling stopAndDiscardLaunchProfileTracerWithHub:hub];
            }
        }

        [SentryLaunchProfiling configureLaunchProfilingForNextLaunchWithOptions:options];
    }];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
