#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryBaggage;
@class SentryTraceHeader;

@interface SentryTracePropagation : NSObject

+ (void)addBaggageHeader:(SentryBaggage *)baggage
                traceHeader:(SentryTraceHeader *)traceHeader
       propagateTraceparent:(BOOL)propagateTraceparent
    tracePropagationTargets:(NSArray *)tracePropagationTargets
                  toRequest:(NSURLSessionTask *)sessionTask;

+ (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets;

@end

NS_ASSUME_NONNULL_END
