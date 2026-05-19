#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryFeedback;
@class SentryId;
@class SentryLogger;
@class SentryOptions;
@class SentryReplayApi;
@class SentryScope;
@class SentryTransactionContext;
@class SentryUser;
@protocol SentrySpan;

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
@class SentryFeedbackAPI;
#endif

// Forward declarations of SentryObjCBridge — a Swift class
// (@objc(SentryObjCBridge)) in the SentryObjCCompat target.
//
// We cannot import its Swift-generated header here because the SentryObjC
// target must stay pure ObjC (no *-Swift.h imports).  These hand-written
// declarations let the compiler resolve selectors without a module import.
//
// LIMITATION: forward declarations only provide link-time safety.  If the
// Swift compat layer renames a selector, the linker will catch it (undefined
// symbol).  But if a parameter or return type changes (e.g. SentryEvent* →
// SentryScope*), the mismatch is invisible until runtime — ObjC dispatches
// on selector name alone and does not verify argument types at link time.
//
// COMPILE-TIME ALTERNATIVE: declaring an ObjC @protocol with these same
// method signatures in SentryObjCTypes (the shared upstream target that both
// SentryObjCCompat and SentryObjC can import) would restore full compile-time
// type checking.  The Swift class would adopt the protocol, and each .m file
// would declare `@interface SentryObjCBridge : NSObject <SentryObjCBridging>`.
// Any signature drift — added/removed methods, changed parameter types — would
// then fail to compile on both sides of the boundary instead of silently
// passing through to a link-time error.
@interface SentryObjCBridge : NSObject

+ (nullable id<SentrySpan>)sdkSpan;
+ (BOOL)sdkIsEnabled;
+ (NSInteger)sdkLastRunStatus;
+ (BOOL)sdkCrashedLastRun;
+ (BOOL)sdkDetectedStartUpCrash;
+ (SentryLogger *)logger;

+ (void)sdkStartWithOptions:(SentryOptions *)options;
+ (void)sdkStartWithConfigureOptions:(void (^)(SentryOptions *))block;

+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event;
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event withScope:(SentryScope *)scope;
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *))block;
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event attachAllThreads:(BOOL)attachAllThreads;

+ (id<SentrySpan>)sdkStartTransactionWithName:(NSString *)name operation:(NSString *)operation;
+ (id<SentrySpan>)sdkStartTransactionWithName:(NSString *)name
                                    operation:(NSString *)operation
                                  bindToScope:(BOOL)bindToScope;
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)ctx;
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)ctx
                                     bindToScope:(BOOL)bindToScope;
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)ctx
                           customSamplingContext:(NSDictionary<NSString *, id> *)samplingCtx;
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)ctx
                                     bindToScope:(BOOL)bindToScope
                           customSamplingContext:(NSDictionary<NSString *, id> *)samplingCtx;

+ (SentryId *)sdkCaptureError:(NSError *)error;
+ (SentryId *)sdkCaptureError:(NSError *)error withScope:(SentryScope *)scope;
+ (SentryId *)sdkCaptureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *))block;
+ (SentryId *)sdkCaptureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads;

+ (SentryId *)sdkCaptureException:(NSException *)exception;
+ (SentryId *)sdkCaptureException:(NSException *)exception withScope:(SentryScope *)scope;
+ (SentryId *)sdkCaptureException:(NSException *)exception
                   withScopeBlock:(void (^)(SentryScope *))block;
+ (SentryId *)sdkCaptureException:(NSException *)exception attachAllThreads:(BOOL)attachAllThreads;

+ (SentryId *)sdkCaptureMessage:(NSString *)message;
+ (SentryId *)sdkCaptureMessage:(NSString *)message withScope:(SentryScope *)scope;
+ (SentryId *)sdkCaptureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *))block;
+ (SentryId *)sdkCaptureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads;

+ (void)sdkCaptureFeedback:(SentryFeedback *)feedback;
+ (void)sdkAddBreadcrumb:(SentryBreadcrumb *)crumb;
+ (void)sdkConfigureScope:(void (^)(SentryScope *))callback;
+ (void)sdkSetUser:(nullable SentryUser *)user;
+ (void)sdkStartSession;
+ (void)sdkEndSession;
+ (void)sdkCrash;
+ (void)sdkReportFullyDisplayed;
+ (void)sdkPauseAppHangTracking;
+ (void)sdkResumeAppHangTracking;
+ (void)sdkFlushWithTimeout:(NSTimeInterval)timeout;
+ (void)sdkClose;

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)sdkStartProfiler;
+ (void)sdkStopProfiler;
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED
+ (SentryReplayApi *)replay;
#endif

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
