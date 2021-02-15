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
    return [self startChildWithName:name operation:operation description:nil];
}

- (id<SentrySpan>)startChildWithName:(NSString *)name
                           operation:(NSString *)operation
                         description:(nullable NSString *)description
{
    return [self startChildWithParentId:_rootSpan.spanId
                                   name:name
                              operation:operation
                            description:description];
}

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                                    name:(NSString *)name
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:_rootSpan.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                           sampled:_rootSpan.context.sampled];
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
    NSMutableDictionary *mutableDictionary =
        [[NSMutableDictionary alloc] initWithDictionary:[_rootSpan serialize]];

    [mutableDictionary removeObjectForKey:@"timestamp"];
    [mutableDictionary removeObjectForKey:@"start_timestamp"];

    return mutableDictionary;
}

@end
