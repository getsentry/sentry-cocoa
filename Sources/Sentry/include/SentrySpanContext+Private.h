#import <SentrySpanContext.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySpanContext ()

- (instancetype)initWithOperation:(NSString *)operation
                           origin:(NSString *)origin
                          sampled:(SentrySampleDecision)sampled
                       sampleRate:(nullable NSNumber *)sampleRate
                       sampleRand:(nullable NSNumber *)sampleRand;

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                         origin:(NSString *)origin
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand;

@end

NS_ASSUME_NONNULL_END
