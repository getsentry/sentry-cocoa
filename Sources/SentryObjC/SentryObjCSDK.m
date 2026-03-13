#import <Foundation/Foundation.h>

// Forward declare SentrySDKInternal to avoid importing headers that require modules.
// At link time, the actual implementation from SentryObjCInternal will be used.
@interface SentrySDKInternal : NSObject
+ (nullable id)span;
+ (BOOL)isEnabled;
+ (void)startWithOptions:(id)options;
+ (void)startWithConfigureOptions:(void (^)(id options))configureOptions;
+ (id)captureEvent:(id)event;
+ (id)captureEvent:(id)event withScope:(id)scope;
+ (id)captureEvent:(id)event withScopeBlock:(void (^)(id scope))block;
+ (id)startTransactionWithName:(NSString *)name operation:(NSString *)operation;
+ (id)startTransactionWithName:(NSString *)name
                     operation:(NSString *)operation
                   bindToScope:(BOOL)bindToScope;
+ (id)startTransactionWithContext:(id)transactionContext;
+ (id)startTransactionWithContext:(id)transactionContext bindToScope:(BOOL)bindToScope;
+ (id)startTransactionWithContext:(id)transactionContext
            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
+ (id)startTransactionWithContext:(id)transactionContext
                      bindToScope:(BOOL)bindToScope
            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
+ (id)captureError:(NSError *)error;
+ (id)captureError:(NSError *)error withScope:(id)scope;
+ (id)captureError:(NSError *)error withScopeBlock:(void (^)(id scope))block;
+ (id)captureException:(NSException *)exception;
+ (id)captureException:(NSException *)exception withScope:(id)scope;
+ (id)captureException:(NSException *)exception withScopeBlock:(void (^)(id scope))block;
+ (id)captureMessage:(NSString *)message;
+ (id)captureMessage:(NSString *)message withScope:(id)scope;
+ (id)captureMessage:(NSString *)message withScopeBlock:(void (^)(id scope))block;
+ (void)captureFeedback:(id)feedback;
+ (void)addBreadcrumb:(id)crumb;
+ (void)configureScope:(void (^)(id scope))callback;
+ (BOOL)crashedLastRun;
+ (BOOL)detectedStartUpCrash;
+ (void)setUser:(nullable id)user;
+ (void)startSession;
+ (void)endSession;
+ (void)crash;
+ (void)reportFullyDisplayed;
+ (void)pauseAppHangTracking;
+ (void)resumeAppHangTracking;
+ (void)flush:(NSTimeInterval)timeout;
+ (void)close;
#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)startProfiler;
+ (void)stopProfiler;
#endif
@end

// Forward declare SentryObjCBridge for metrics, logger, and replay access.
@interface SentryObjCBridge : NSObject
+ (id)logger;
+ (id)replay;
@end

// Import the public header which declares SentrySDK
#import "SentryObjCMetricsApiImpl.h"
#import "SentryObjCSDK.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryObjCSDK

+ (nullable id<SentrySpan>)span
{
    return [SentrySDKInternal span];
}

+ (BOOL)isEnabled
{
    return [SentrySDKInternal isEnabled];
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

+ (id<SentryObjCMetricsApi>)metrics
{
    static SentryObjCMetricsApiImpl *_metricsApi = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ _metricsApi = [[SentryObjCMetricsApiImpl alloc] init]; });
    return _metricsApi;
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
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext
                                    customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDKInternal startTransactionWithContext:transactionContext
                                              bindToScope:bindToScope
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

+ (void)captureFeedback:(SentryFeedback *)feedback
{
    [SentrySDKInternal captureFeedback:feedback];
}

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

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)startProfiler
{
    [SentrySDKInternal startProfiler];
}

+ (void)stopProfiler
{
    [SentrySDKInternal stopProfiler];
}
#endif

@end

NS_ASSUME_NONNULL_END
