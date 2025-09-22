#if !SDK_V9

#    import "SentrySDK.h"
#    import "SentrySwift.h"

@implementation SentrySDK

+ (void)startWithOptions:(SentryOptions *_Nonnull)options
{
    [SentrySDKSwift startWithOptions:options];
}

+ (void)startWithConfigureOptions:(void (^_Nonnull)(SentryOptions *_Nonnull))configureOptions
{
    [SentrySDKSwift startWithConfigureOptions:configureOptions];
}

+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event
{
    return [SentrySDKSwift captureEvent:event];
}

+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event
                         withScope:(SentryScope *_Nonnull)scope
{
    return [SentrySDKSwift captureEvent:event withScope:scope];
}

+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event
                    withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
{
    return [SentrySDKSwift captureEvent:event withScopeBlock:block];
}

+ (id<SentrySpan> _Nonnull)startTransactionWithName:(NSString *_Nonnull)name
                                          operation:(NSString *_Nonnull)operation
{
    return [SentrySDKSwift startTransactionWithName:name operation:operation];
}

+ (id<SentrySpan> _Nonnull)startTransactionWithName:(NSString *_Nonnull)name
                                          operation:(NSString *_Nonnull)operation
                                        bindToScope:(BOOL)bindToScope
{
    return [SentrySDKSwift startTransactionWithName:name
                                          operation:operation
                                        bindToScope:bindToScope];
}

+ (id<SentrySpan> _Nonnull)startTransactionWithContext:
    (SentryTransactionContext *_Nonnull)transactionContext
{
    return [SentrySDKSwift startTransactionWithContext:transactionContext];
}

+ (id<SentrySpan> _Nonnull)startTransactionWithContext:
                               (SentryTransactionContext *_Nonnull)transactionContext
                                           bindToScope:(BOOL)bindToScope
{
    return [SentrySDKSwift startTransactionWithContext:transactionContext bindToScope:bindToScope];
}

+ (id<SentrySpan> _Nonnull)
    startTransactionWithContext:(SentryTransactionContext *_Nonnull)transactionContext
                    bindToScope:(BOOL)bindToScope
          customSamplingContext:(NSDictionary<NSString *, id> *_Nonnull)customSamplingContext
{
    return [SentrySDKSwift startTransactionWithContext:transactionContext
                                           bindToScope:bindToScope
                                 customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan> _Nonnull)
    startTransactionWithContext:(SentryTransactionContext *_Nonnull)transactionContext
          customSamplingContext:(NSDictionary<NSString *, id> *_Nonnull)customSamplingContext
{
    return [SentrySDKSwift startTransactionWithContext:transactionContext
                                 customSamplingContext:customSamplingContext];
}

+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error
{
    return [SentrySDKSwift captureError:error];
}

+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error withScope:(SentryScope *_Nonnull)scope
{
    return [SentrySDKSwift captureError:error withScope:scope];
}

+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error
                    withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
{
    return [SentrySDKSwift captureError:error withScopeBlock:block];
}

+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
{
    return [SentrySDKSwift captureException:exception];
}

+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
                             withScope:(SentryScope *_Nonnull)scope
{
    return [SentrySDKSwift captureException:exception withScope:scope];
}

+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
                        withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
{
    return [SentrySDKSwift captureException:exception withScopeBlock:block];
}

+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message
{
    return [SentrySDKSwift captureMessage:message];
}

+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message
                           withScope:(SentryScope *_Nonnull)scope
{
    return [SentrySDKSwift captureMessage:message withScope:scope];
}

+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message
                      withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
{
    return [SentrySDKSwift captureMessage:message withScopeBlock:block];
}

+ (void)captureUserFeedback:(SentryUserFeedback *_Nonnull)userFeedback
    DEPRECATED_MSG_ATTRIBUTE("Use SentrySDK.back or use or configure our new managed UX with "
                             "SentryOptions.configureUserFeedback.")
{
    [SentrySDKSwift captureUserFeedback:userFeedback];
}

+ (void)captureFeedback:(SentryFeedback *_Nonnull)feedback
{
    [SentrySDKSwift captureFeedback:feedback];
}

+ (SentryFeedbackAPI *_Nonnull)feedback
{
    return [SentrySDKSwift feedback];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *_Nonnull)crumb
{
    [SentrySDKSwift addBreadcrumb:crumb];
}

+ (void)configureScope:(void (^_Nonnull)(SentryScope *_Nonnull))callback
{
    [SentrySDKSwift configureScope:callback];
}

+ (BOOL)crashedLastRun
{
    return [SentrySDKSwift crashedLastRun];
}

+ (BOOL)detectedStartUpCrash
{
    return [SentrySDKSwift detectedStartUpCrash];
}

+ (void)setUser:(SentryUser *_Nullable)user
{
    [SentrySDKSwift setUser:user];
}

+ (void)startSession
{
    [SentrySDKSwift startSession];
}

+ (void)endSession
{
    [SentrySDKSwift endSession];
}

+ (void)crash
{
    [SentrySDKSwift crash];
}

+ (void)reportFullyDisplayed
{
    [SentrySDKSwift reportFullyDisplayed];
}

+ (void)pauseAppHangTracking
{
    [SentrySDKSwift pauseAppHangTracking];
}

+ (void)resumeAppHangTracking
{
    [SentrySDKSwift resumeAppHangTracking];
}

+ (void)flush:(NSTimeInterval)timeout
{
    [SentrySDKSwift flush:timeout];
}

+ (void)close
{
    [SentrySDKSwift close];
}

+ (void)startProfiler
{
    [SentrySDKSwift startProfiler];
}

+ (void)stopProfiler
{
    [SentrySDKSwift stopProfiler];
}

+ (BOOL)isEnabled
{
    return [SentrySDKSwift isEnabled];
}

+ (SentryLogger *)logger
{
    return [SentrySDKSwift logger];
}

+ (SentryReplayApi *_Nonnull)replay
{
    return [SentrySDKSwift replay];
}

+ (id<SentrySpan> _Nullable)span;
{
    return [SentrySDKSwift span];
}

@end

#endif // !SDK_V9
