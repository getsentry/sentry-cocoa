#import "SentryProfilingSwiftHelpers.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryClient.h"
#    import "SentryLogC.h"
#    import "SentryOptionsInternal+Private.h"
#    import "SentryProfiler+Private.h"
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
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
