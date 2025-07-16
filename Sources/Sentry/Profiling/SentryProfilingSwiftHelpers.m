#import "SentryProfilingSwiftHelpers.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryLogC.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfiler+Private.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySwift.h"

BOOL
isContinuousProfilingEnabled(SentryClient *client)
{
    return [client.options isContinuousProfilingEnabled];
}

BOOL
isContinuousProfilingV2Enabled(SentryClient *client)
{
    return [client.options isContinuousProfilingV2Enabled];
}

BOOL
isProfilingCorrelatedToTraces(SentryClient *client)
{
    return [client.options isProfilingCorrelatedToTraces];
}

SentryProfileOptions *
getProfiling(SentryClient *client)
{
    return client.options.profiling;
}

NSString *
stringFromSentryID(SentryId *sentryID)
{
    return sentryID.sentryIdString;
}

NSDate *
getDate(void)
{
    return [SentryDependencyContainer.sharedInstance.dateProvider date];
}

uint64_t
getSystemTime(void)
{
    return SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
}

SentryId *
getSentryId(void)
{
    return [[SentryId alloc] init];
}

SentryProfileOptions *
getSentryProfileOptions(void)
{
    return [[SentryProfileOptions alloc] init];
}

BOOL
isTraceLifecycle(SentryProfileOptions *options)
{
    return options.lifecycle == SentryProfileLifecycleTrace;
}

float
sessionSampleRate(SentryProfileOptions *options)
{
    return options.sessionSampleRate;
}

BOOL
profileAppStarts(SentryProfileOptions *options)
{
    return options.profileAppStarts;
}

BOOL
isTrace(int lifecycle)
{
    return lifecycle == SentryProfileLifecycleTrace;
}

BOOL
isManual(int lifecycle)
{
    return lifecycle == SentryProfileLifecycleManual;
}

SentrySpanId *
getParentSpanID(SentryTransactionContext *context)
{
    return context.parentSpanId;
}

SentryId *
getTraceID(SentryTransactionContext *context)
{
    return context.traceId;
}

BOOL
isNotSampled(SentryTransactionContext *context)
{
    return context.sampled != kSentrySampleDecisionYes;
}

void
dispatchAsync(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block)
{
    [wrapper dispatchAsyncWithBlock:block];
}

void
dispatchAsyncOnMain(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block)
{
    [wrapper dispatchAsyncOnMainQueue:block];
}

void
removeObserver(id object)
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:object
                                                                                  name:nil
                                                                                object:nil];
}

void
addObserver(id observer, SEL selector, NSNotificationName name, _Nullable id object)
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper addObserver:observer
                                                                                  selector:selector
                                                                                      name:name
                                                                                    object:object];
}

void
postNotification(NSNotification *notification)
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        postNotification:notification];
}

id
addObserverForName(NSNotificationName name, dispatch_block_t block)
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserverForName:name
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull notification) { block(); }];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
