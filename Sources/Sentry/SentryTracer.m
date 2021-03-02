#import "SentryTracer.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransaction.h"

@implementation SentryTracer {
    SentrySpan *_rootSpan;
    NSMutableArray<id<SentrySpan>> *_spans;
    SentryHub *_hub;
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
{
    if ([super init]) {
        _rootSpan = [[SentrySpan alloc] initWithTracer:self
                                                  name:transactionContext.name
                                               context:transactionContext];
        _spans = [[NSMutableArray alloc] init];
        _hub = hub;
    }

    return self;
}

- (id<SentrySpan>)startChildWithName:(NSString *)name operation:(NSString *)operation
{
    return [_rootSpan startChildWithName:name operation:operation];
}

- (id<SentrySpan>)startChildWithName:(NSString *)name
                           operation:(NSString *)operation
                         description:(nullable NSString *)description
{
    return [_rootSpan startChildWithName:name operation:operation description:description];
}

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                                    name:(NSString *)name
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:_rootSpan.context.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                           sampled:_rootSpan.context.sampled];
    context.spanDescription = description;

    SentrySpan *span = [[SentrySpan alloc] initWithName:name context:context];
    @synchronized(_spans) {
        [_spans addObject:span];
    }
    return span;
}

- (NSString *)name
{
    return _rootSpan.name;
}

- (SentrySpanContext *)context
{
    return _rootSpan.context;
}

- (NSDate *)timestamp
{
    return _rootSpan.timestamp;
}

- (void)setTimestamp:(NSDate *)timestamp
{
    _rootSpan.timestamp = timestamp;
}

- (NSDate *)startTimestamp
{
    return _rootSpan.startTimestamp;
}

- (void)setStartTimestamp:(NSDate *)startTimestamp
{
    _rootSpan.startTimestamp = startTimestamp;
}

- (NSDictionary<NSString *, id> *)data
{
    return _rootSpan.data;
}

- (BOOL)isFinished
{
    return _rootSpan.isFinished;
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
    [_rootSpan setDataValue:value forKey:key];
}

- (void)finish
{
    [_rootSpan finish];
    [self captureTransaction];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    [_rootSpan finishWithStatus:status];
    [self captureTransaction];
}

- (void)captureTransaction
{
    NSArray *spans;
    @synchronized(_spans) {
        spans = [[NSArray alloc] initWithArray:_spans];
    }

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self childs:spans];
    [_hub captureEvent:transaction];
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
