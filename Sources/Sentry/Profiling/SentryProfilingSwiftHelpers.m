#import "SentryProfilingSwiftHelpers.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient.h"
#    import "SentryDependencyContainerSwiftHelper.h"
#    import "SentryHub.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLogC.h"
#    import "SentryProfileConfiguration.h"
#    import "SentryProfiler+Private.h"
#    import "SentrySDK+Private.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySwift.h"

BOOL
sentry_isContinuousProfilingEnabled(SentryClientInternal *client)
{
    return [client.options isContinuousProfilingEnabled];
}

BOOL
sentry_isProfilingCorrelatedToTraces(SentryClientInternal *client)
{
    return [client.options isProfilingCorrelatedToTraces];
}

SentryProfileOptions *_Nullable sentry_getProfiling(SentryClientInternal *client)
{
    return client.options.profiling;
}

NSString *
sentry_stringFromSentryID(SentryId *sentryID)
{
    return sentryID.sentryIdString;
}

NSDate *
sentry_getDate(void)
{
    return [SentryDependencyContainer.sharedInstance.dateProvider date];
}

uint64_t
sentry_getSystemTime(void)
{
    return SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
}

SentryId *
sentry_getSentryId(void)
{
    return [[SentryId alloc] init];
}

SentryProfileOptions *
sentry_getSentryProfileOptions(void)
{
    return [[SentryProfileOptions alloc] init];
}

BOOL
sentry_isTraceLifecycle(SentryProfileOptions *options)
{
    return options.lifecycle == SentryProfileLifecycleTrace;
}

float
sentry_sessionSampleRate(SentryProfileOptions *options)
{
    return options.sessionSampleRate;
}

BOOL
sentry_profileAppStarts(SentryProfileOptions *options)
{
    return options.profileAppStarts;
}

SentrySpanId *_Nullable sentry_getParentSpanID(SentryTransactionContext *context)
{
    return context.parentSpanId;
}

SentryId *
sentry_getTraceID(SentryTransactionContext *context)
{
    return context.traceId;
}

BOOL
sentry_isNotSampled(SentryTransactionContext *context)
{
    return context.sampled != kSentrySampleDecisionYes;
}

void
sentry_dispatchAsync(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block)
{
    [wrapper dispatchAsyncWithBlock:block];
}

void
sentry_dispatchAsyncOnMainIfNotMainThread(
    SentryDispatchQueueWrapper *wrapper, dispatch_block_t block)
{
    [wrapper dispatchAsyncOnMainQueueIfNotMainThread:block];
}

void
sentry_removeObserver(id object)
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:object
                                                                                  name:nil
                                                                                object:nil];
}

void
sentry_addObserver(id observer, SEL selector, NSNotificationName name, _Nullable id object)
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper addObserver:observer
                                                                                  selector:selector
                                                                                      name:name
                                                                                    object:object];
}

void
sentry_postNotification(NSNotification *notification)
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        postNotification:notification];
}

id
sentry_addObserverForName(NSNotificationName name, dispatch_block_t block)
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserverForName:name
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull notification) { block(); }];
}

NSTimer *
sentry_scheduledTimer(NSTimeInterval interval, BOOL repeats, dispatch_block_t block)
{
    return [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                               repeats:repeats
                                 block:^(NSTimer *_Nonnull timer) { block(); }];
}

NSTimer *
sentry_scheduledTimerWithTarget(
    NSTimeInterval interval, id target, SEL selector, _Nullable id userInfo, BOOL repeats)
{
    return [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                                target:target
                              selector:selector
                              userInfo:userInfo
                               repeats:repeats];
}

#    if SENTRY_HAS_UIKIT
BOOL
sentry_appHangsDisabled(void)
{
    SentryOptions *options = [[[SentrySDKInternal currentHub] getClient] options];
    if (options == nil) {
        return NO;
    }
    return [options isAppHangTrackingDisabled];
}
BOOL
sentry_autoPerformanceTracingDisabled(void)
{
    SentryOptions *options = [[[SentrySDKInternal currentHub] getClient] options];
    if (options == nil) {
        return YES;
    }
    return ![options enableAutoPerformanceTracing];
}
void
sentry_startFramesTracker(void)
{
    [SentryDependencyContainer.sharedInstance.framesTracker start];
}

void
sentry_stopFramesTracker(void)
{
    [SentryDependencyContainer.sharedInstance.framesTracker stop];
}

void
sentry_framesTrackerResetProfilingTimestamps(void)
{
    [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
}

SentryScreenFrames *
sentry_framesTrackerGetCurrentFrames(void)
{
    return [SentryDependencyContainer.sharedInstance.framesTracker currentFrames];
}
#    endif // SENTRY_HAS_UIKIT

void
sentry_configureContinuousProfiling(SentryOptions *options)
{
    if (options.configureProfiling == nil) {
        SENTRY_LOG_DEBUG(@"Continuous profiling V2 configuration not set by SDK consumer, nothing "
                         @"to do here.");
        return;
    }

    SentryProfileOptions *_Nonnull profilingOptions = sentry_getSentryProfileOptions();
    options.profiling = profilingOptions;
    options.configureProfiling(profilingOptions);

    if (sentry_isTraceLifecycle(profilingOptions) && !options.isTracingEnabled) {
        SENTRY_LOG_WARN(
            @"Tracing must be enabled in order to configure profiling with trace lifecycle.");
        return;
    }

    // if a launch profiler was started, sentry_profileConfiguration will have been set at that time
    // with the hydrated options that were persisted from the previous SDK start, which are used to
    // help determine when/how to stop the launch profile. otherwise, there won't yet be a
    // SentryProfileConfiguration instance, so we'll instantiate one which will be used to access
    // the profile session sample rate henceforth
    if (sentry_profileConfiguration == nil) {
        sentry_profileConfiguration =
            [[SentryProfileConfiguration alloc] initWithProfileOptions:profilingOptions];
    }

    sentry_reevaluateSessionSampleRate();

    SENTRY_LOG_DEBUG(@"Configured profiling options: <%@: {\n  lifecycle: %@\n  sessionSampleRate: "
                     @"%.2f\n  profileAppStarts: %@\n}",
        options.profiling, sentry_isTraceLifecycle(profilingOptions) ? @"trace" : @"manual",
        sentry_sessionSampleRate(profilingOptions),
        sentry_profileAppStarts(profilingOptions) ? @"YES" : @"NO");
}

void
sentry_sdkInitProfilerTasks(SentryOptions *options, SentryHubInternal *hub)
{
    // get the configuration options from the last time the launch config was written; it may be
    // different than the new options the SDK was just started with
    SentryProfileConfiguration *configurationFromLaunch = sentry_profileConfiguration;

    sentry_configureContinuousProfiling(options);

    sentry_dispatchAsync(SentryDependencyContainerSwiftHelper.dispatchQueueWrapper, ^{
        if (configurationFromLaunch.isProfilingThisLaunch) {
            BOOL shouldStopAndTransmitLaunchProfile = YES;

            BOOL profileIsContinuousV2 = configurationFromLaunch.profileOptions != nil;
            BOOL v2LifecycleIsManual = profileIsContinuousV2
                && !sentry_isTraceLifecycle(SENTRY_UNWRAP_NULLABLE(
                    SentryProfileOptions, configurationFromLaunch.profileOptions));

#    if SENTRY_HAS_UIKIT
            BOOL v2LifecycleIsTrace = profileIsContinuousV2
                && sentry_isTraceLifecycle(SENTRY_UNWRAP_NULLABLE(
                    SentryProfileOptions, configurationFromLaunch.profileOptions));
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
                sentry_stopAndDiscardLaunchProfileTracer(hub);
            }
        }

        sentry_configureLaunchProfilingForNextLaunch(options);
    });
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
