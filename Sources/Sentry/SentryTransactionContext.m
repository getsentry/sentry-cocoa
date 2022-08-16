#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTransactionContext

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation];
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
{
    if (self = [super initWithOperation:operation]) {
        _name = [NSString stringWithString:name];
        _nameSource = source;
        self.parentSampled = false;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation
                      sampled:sampled];
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
{
    if (self = [super initWithOperation:operation sampled:sampled]) {
        _name = [NSString stringWithString:name];
        _nameSource = source;
        self.parentSampled = false;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                   operation:(nonnull NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation
                      traceId:traceId
                       spanId:spanId
                 parentSpanId:parentSpanId
                parentSampled:parentSampled];
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(nonnull NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
{
    if (self = [super initWithTraceId:traceId
                               spanId:spanId
                             parentId:parentSpanId
                            operation:operation
                              sampled:false]) {
        _name = [NSString stringWithString:name];
        _nameSource = source;
        self.parentSampled = parentSampled;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
