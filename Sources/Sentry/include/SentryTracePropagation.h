#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryBaggage;
@class SentryTraceHeader;

@interface SentryTracePropagation : NSObject

+ (void)addBaggageHeader:(nullable SentryBaggage *)baggage
                traceHeader:(SentryTraceHeader *)traceHeader
       propagateTraceparent:(BOOL)propagateTraceparent
    tracePropagationTargets:(NSArray *_Nullable)tracePropagationTargets
                  toRequest:(NSURLSessionTask *)sessionTask;

/// Injects the trace headers into a mutable request that has not been handed to a task yet.
///
/// Unlike @c addBaggageHeader:...toRequest: this never touches a live @c NSURLSessionTask, so it is
/// safe to call at task-creation time. The caller owns @c request and must not have created a task
/// from it yet.
+ (void)addTraceHeaderFieldsToMutableRequest:(NSMutableURLRequest *)request
                                     baggage:(nullable SentryBaggage *)baggage
                                 traceHeader:(SentryTraceHeader *)traceHeader
                        propagateTraceparent:(BOOL)propagateTraceparent
                     tracePropagationTargets:(NSArray *_Nullable)tracePropagationTargets;

+ (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets;

@end

NS_ASSUME_NONNULL_END
