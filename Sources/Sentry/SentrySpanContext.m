#import "SentrySpanContext.h"
#import "SentryLog.h"
#import "SentrySampleDecision+Private.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySpanContext

#pragma mark - Public

- (instancetype)initWithOperation:(NSString *)operation
{
    return [self initWithOperation:operation sampled:kSentrySampleDecisionUndecided];
}

- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled
{
    return [self initWithOperation:operation sampled:sampled sampleRate:nil sampleRand:nil];
}

- (instancetype)initWithOperation:(NSString *)operation
                          sampled:(SentrySampleDecision)sampled
                       sampleRate:(nullable NSNumber *)sampleRate
                       sampleRand:(nullable NSNumber *)sampleRand
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                       operation:operation
                         sampled:sampled
                      sampleRate:sampleRate
                      sampleRand:sampleRand];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                         sampled:sampled
                      sampleRate:nil
                      sampleRand:nil];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                 spanDescription:nil
                         sampled:sampled
                      sampleRate:sampleRate
                      sampleRand:sampleRand];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                 spanDescription:description
                          origin:SentryTraceOrigin.manual
                         sampled:sampled
                      sampleRate:nil
                      sampleRand:nil];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                 spanDescription:description
                          origin:SentryTraceOrigin.manual
                         sampled:sampled
                      sampleRate:sampleRate
                      sampleRand:sampleRand];
}

#pragma mark - Private

- (instancetype)initWithOperation:(NSString *)operation
                           origin:(NSString *)origin
                          sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                       operation:operation
                 spanDescription:nil
                          origin:origin
                         sampled:sampled
                      sampleRate:nil
                      sampleRand:nil];
}

- (instancetype)initWithOperation:(NSString *)operation
                           origin:(NSString *)origin
                          sampled:(SentrySampleDecision)sampled
                       sampleRate:(nullable NSNumber *)sampleRate
                       sampleRand:(nullable NSNumber *)sampleRand
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                       operation:operation
                 spanDescription:nil
                          origin:origin
                         sampled:sampled
                      sampleRate:sampleRate
                      sampleRand:sampleRand];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                         origin:(NSString *)origin
                        sampled:(SentrySampleDecision)sampled
{
    return [self initWithTraceId:traceId
                          spanId:spanId
                        parentId:parentId
                       operation:operation
                 spanDescription:description
                          origin:origin
                         sampled:sampled
                      sampleRate:nil
                      sampleRand:nil];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                         origin:(NSString *)origin
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand
{
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
        _parentSpanId = parentId;
        _sampled = sampled;
        _sampleRate = sampleRate;
        _sampleRand = sampleRand;
        _operation = operation;
        _spanDescription = description;
        _origin = origin;

        SENTRY_LOG_DEBUG(
            @"Created span context with trace ID %@; span ID %@; parent span ID %@; operation %@",
            traceId.sentryIdString, spanId.sentrySpanIdString, parentId.sentrySpanIdString,
            operation);
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *mutabledictionary = @{
        @"type" : SENTRY_TRACE_TYPE,
        @"span_id" : self.spanId.sentrySpanIdString,
        @"trace_id" : self.traceId.sentryIdString,
        @"op" : self.operation,
        @"origin" : self.origin
    }
                                                 .mutableCopy;

    // Since we guard for 'undecided', we'll
    // either send it if it's 'true' or 'false'.
    if (self.sampled != kSentrySampleDecisionUndecided) {
        [mutabledictionary setValue:valueForSentrySampleDecision(self.sampled) forKey:@"sampled"];
    }

    if (self.sampleRate != nil) {
        [mutabledictionary setValue:[NSString stringWithFormat:@"%f", self.sampleRate.floatValue]
                             forKey:@"sample_rate"];
    }

    if (self.sampleRand != nil) {
        [mutabledictionary setValue:[NSString stringWithFormat:@"%f", self.sampleRate.floatValue]
                             forKey:@"sample_rand"];
    }

    if (self.spanDescription != nil) {
        [mutabledictionary setValue:self.spanDescription forKey:@"description"];
    }

    if (self.parentSpanId != nil) {
        [mutabledictionary setValue:self.parentSpanId.sentrySpanIdString forKey:@"parent_span_id"];
    }

    return mutabledictionary;
}
@end

NS_ASSUME_NONNULL_END
