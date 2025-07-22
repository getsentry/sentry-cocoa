#import "SentryProfilingConditionals.h"
#import "SentrySDK.h"
#import "SentrySDKInternal.h"

@implementation SentrySDK

+ (id<SentrySpan>)span
{
    return [SentrySDKInternal span];
}

+ (BOOL)isEnabled
{
    return [SentrySDKInternal isEnabled];
}

#if SENTRY_TARGET_REPLAY_SUPPORTED
+ (SentryReplayApi *)replay
{
    return [SentrySDKInternal replay];
}
#endif // SENTRY_TARGET_REPLAY_SUPPORTED

+ (SentryLogger *)logger
{
    return [SentrySDKInternal logger];
}

+ (void)startWithOptions:(SentryOptions *)options
{
    [SentrySDKInternal startWithOptions:options];
}

+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
{
    [SentrySDKInternal startWithConfigureOptions:configureOptions];
}

+ (SentryId *)captureEvent:(SentryEvent *)event
{
    return [SentrySDKInternal captureEvent:event];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [SentrySDKInternal captureEvent:event withScope:scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentrySDKInternal captureEvent:event withScopeBlock:block];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [SentrySDKInternal startTransactionWithName:name operation:operation];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return [SentrySDKInternal startTransactionWithName:name
                                             operation:operation
                                           bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext
                                              bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext
                                              bindToScope:bindToScope
                                    customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext
                                    customSamplingContext:customSamplingContext];
}

+ (SentryId *)captureError:(NSError *)error
{
    return [SentrySDKInternal captureError:error];
}

+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    return [SentrySDKInternal captureError:error withScope:scope];
}

+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentrySDKInternal captureError:error withScopeBlock:block];
}

+ (SentryId *)captureException:(NSException *)exception
{
    return [SentrySDKInternal captureException:exception];
}

+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    return [SentrySDKInternal captureException:exception withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentrySDKInternal captureException:exception withScopeBlock:block];
}

+ (SentryId *)captureMessage:(NSString *)message
{
    return [SentrySDKInternal captureMessage:message];
}

+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    return [SentrySDKInternal captureMessage:message withScope:scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentrySDKInternal captureMessage:message withScopeBlock:block];
}

#if !SDK_V9

+ (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    [SentrySDKInternal captureUserFeedback:userFeedback];
}

#endif

+ (void)captureFeedback:(SentryFeedback *)feedback
{
    [SentrySDKInternal captureFeedback:feedback];
}

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
+ (SentryFeedbackAPI *)feedback
{
    return [SentrySDKInternal feedback];
}
#endif

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDKInternal addBreadcrumb:crumb];
}

+ (void)configureScope:(void (^)(SentryScope *scope))callback
{
    [SentrySDKInternal configureScope:callback];
}

+ (BOOL)crashedLastRun
{
    return [SentrySDKInternal crashedLastRun];
}

+ (BOOL)detectedStartUpCrash
{
    return [SentrySDKInternal detectedStartUpCrash];
}

+ (void)setUser:(nullable SentryUser *)user
{
    [SentrySDKInternal setUser:user];
}

+ (void)startSession
{
    [SentrySDKInternal startSession];
}

+ (void)endSession
{
    [SentrySDKInternal endSession];
}

+ (void)crash
{
    [SentrySDKInternal crash];
}

+ (void)reportFullyDisplayed
{
    [SentrySDKInternal reportFullyDisplayed];
}

+ (void)pauseAppHangTracking
{
    [SentrySDKInternal pauseAppHangTracking];
}

+ (void)resumeAppHangTracking
{
    [SentrySDKInternal resumeAppHangTracking];
}

+ (void)flush:(NSTimeInterval)timeout
{
    [SentrySDKInternal flush:timeout];
}

+ (void)close
{
    [SentrySDKInternal close];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED

+ (void)startProfiler
{
    [SentrySDKInternal startProfiler];
}

+ (void)stopProfiler
{
    [SentrySDKInternal stopProfiler];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end
