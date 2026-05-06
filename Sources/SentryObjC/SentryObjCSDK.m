#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

#if __has_include(<SentryObjCTypes/SentryObjCBridging.h>)
#    import <SentryObjCTypes/SentryObjCBridging.h>
#else
#    import "SentryObjCBridging.h"
#endif

@class SentryReplayApi;

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
@class SentryFeedbackAPI;
#endif

// SentryObjCBridge ships in the same SDK and conforms to SentryObjCBridging
// (declared in SentryObjCTypes). Adopting the protocol gives this file typed
// access to the bridge's class methods without importing SentryObjCBridge-Swift.h.
// `replay` and `feedback` are conditionally available and aren't part of the
// protocol — they're declared here as additional class methods on the bridge.
@interface SentryObjCBridge : NSObject <SentryObjCBridging>
+ (SentryReplayApi *)replay;
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
+ (SentryFeedbackAPI *)sdkFeedback;
#endif
@end

#import "SentryLastRunStatus.h"
#import "SentryMetricsApiImpl.h"
#import "SentryObjCSDK.h"

extern void SentryBridgeCallbacksForOptions(SentryOptions *_Nonnull options);

NS_ASSUME_NONNULL_BEGIN

@implementation SentryObjCSDK

+ (nullable id<SentrySpan>)span
{
    return [SentryObjCBridge sdkSpan];
}

+ (BOOL)isEnabled
{
    return [SentryObjCBridge sdkIsEnabled];
}

#if SENTRY_OBJC_REPLAY_SUPPORTED
+ (SentryReplayApi *)replay
{
    return [SentryObjCBridge replay];
}
#endif

+ (SentryLogger *)logger
{
    return [SentryObjCBridge logger];
}

+ (id<SentryMetricsApi>)metrics
{
    static SentryMetricsApiImpl *_metricsApi = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ _metricsApi = [[SentryMetricsApiImpl alloc] init]; });
    return _metricsApi;
}

+ (void)startWithOptions:(SentryOptions *)options
{
    SentryBridgeCallbacksForOptions(options);
    [SentryObjCBridge sdkStartWithOptions:options];
}

+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
{
    [SentryObjCBridge sdkStartWithConfigureOptions:^(SentryOptions *options) {
        configureOptions(options);
        SentryBridgeCallbacksForOptions(options);
    }];
}

+ (SentryId *)captureEvent:(SentryEvent *)event
{
    return [SentryObjCBridge sdkCaptureEvent:event];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [SentryObjCBridge sdkCaptureEvent:event withScope:scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentryObjCBridge sdkCaptureEvent:event withScopeBlock:block];
}

+ (SentryId *)captureEvent:(SentryEvent *)event attachAllThreads:(BOOL)attachAllThreads
{
    return [SentryObjCBridge sdkCaptureEvent:event attachAllThreads:attachAllThreads];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [SentryObjCBridge sdkStartTransactionWithName:name operation:operation];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return [SentryObjCBridge sdkStartTransactionWithName:name
                                               operation:operation
                                             bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
{
    return [SentryObjCBridge sdkStartTransactionWithContext:transactionContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
{
    return [SentryObjCBridge sdkStartTransactionWithContext:transactionContext
                                                bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentryObjCBridge sdkStartTransactionWithContext:transactionContext
                                      customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentryObjCBridge sdkStartTransactionWithContext:transactionContext
                                                bindToScope:bindToScope
                                      customSamplingContext:customSamplingContext];
}

+ (SentryId *)captureError:(NSError *)error
{
    return [SentryObjCBridge sdkCaptureError:error];
}

+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    return [SentryObjCBridge sdkCaptureError:error withScope:scope];
}

+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentryObjCBridge sdkCaptureError:error withScopeBlock:block];
}

+ (SentryId *)captureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads
{
    return [SentryObjCBridge sdkCaptureError:error attachAllThreads:attachAllThreads];
}

+ (SentryId *)captureException:(NSException *)exception
{
    return [SentryObjCBridge sdkCaptureException:exception];
}

+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    return [SentryObjCBridge sdkCaptureException:exception withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentryObjCBridge sdkCaptureException:exception withScopeBlock:block];
}

+ (SentryId *)captureException:(NSException *)exception attachAllThreads:(BOOL)attachAllThreads
{
    return [SentryObjCBridge sdkCaptureException:exception attachAllThreads:attachAllThreads];
}

+ (SentryId *)captureMessage:(NSString *)message
{
    return [SentryObjCBridge sdkCaptureMessage:message];
}

+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    return [SentryObjCBridge sdkCaptureMessage:message withScope:scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *scope))block
{
    return [SentryObjCBridge sdkCaptureMessage:message withScopeBlock:block];
}

+ (SentryId *)captureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads
{
    return [SentryObjCBridge sdkCaptureMessage:message attachAllThreads:attachAllThreads];
}

+ (void)captureFeedback:(SentryFeedback *)feedback
{
    [SentryObjCBridge sdkCaptureFeedback:feedback];
}

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
+ (SentryFeedbackAPI *)feedback
{
    return [SentryObjCBridge sdkFeedback];
}
#endif

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentryObjCBridge sdkAddBreadcrumb:crumb];
}

+ (void)configureScope:(void (^)(SentryScope *scope))callback
{
    [SentryObjCBridge sdkConfigureScope:callback];
}

+ (BOOL)crashedLastRun
{
    return [SentryObjCBridge sdkCrashedLastRun];
}

+ (SentryLastRunStatus)lastRunStatus
{
    return (SentryLastRunStatus)[SentryObjCBridge sdkLastRunStatus];
}

+ (BOOL)detectedStartUpCrash
{
    return [SentryObjCBridge sdkDetectedStartUpCrash];
}

+ (void)setUser:(nullable SentryUser *)user
{
    [SentryObjCBridge sdkSetUser:user];
}

+ (void)startSession
{
    [SentryObjCBridge sdkStartSession];
}

+ (void)endSession
{
    [SentryObjCBridge sdkEndSession];
}

+ (void)crash
{
    [SentryObjCBridge sdkCrash];
}

+ (void)reportFullyDisplayed
{
    [SentryObjCBridge sdkReportFullyDisplayed];
}

+ (void)pauseAppHangTracking
{
    [SentryObjCBridge sdkPauseAppHangTracking];
}

+ (void)resumeAppHangTracking
{
    [SentryObjCBridge sdkResumeAppHangTracking];
}

+ (void)flush:(NSTimeInterval)timeout
{
    [SentryObjCBridge sdkFlushWithTimeout:timeout];
}

+ (void)close
{
    [SentryObjCBridge sdkClose];
}

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)startProfiler
{
    [SentryObjCBridge sdkStartProfiler];
}

+ (void)stopProfiler
{
    [SentryObjCBridge sdkStopProfiler];
}
#endif

@end

NS_ASSUME_NONNULL_END
