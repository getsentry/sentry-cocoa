#import "SentryTracer.h"
#import "SentryHub.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"


static const void *spanTimestampObserver = &spanTimestampObserver;

@implementation SentryTracer {
    SentrySpan *_rootSpan;
    NSMutableArray<id<SentrySpan>> *_spans;
    SentryHub *_hub;
    SentrySpanStatus _finishStatus;
    BOOL _shouldBeFinished;
    BOOL _waitForChildren;
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
{
    return [self initWithTransactionContext:transactionContext hub:hub waitForChildren:NO];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                           waitForChildren:(BOOL)waitForChildren
{
    if ([super init]) {
        _rootSpan = [[SentrySpan alloc] initWithTracer:self context:transactionContext];
        self.name = transactionContext.name;
        _spans = [[NSMutableArray alloc] init];
        _hub = hub;
        _waitForChildren = waitForChildren;
        _finishStatus = kSentrySpanStatusUndefined;
    }

    return self;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
{
    return [_rootSpan startChildWithOperation:operation];
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
{
    return [_rootSpan startChildWithOperation:operation description:description];
}

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
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

    SentrySpan *child = [[SentrySpan alloc] initWithTracer:self context:context];
    
    if(_waitForChildren)
    {
        [child addObserver:self
                forKeyPath:@"timestamp"
                   options:NSKeyValueObservingOptionNew
                   context:&spanTimestampObserver];
    }
    
    @synchronized(_spans) {
        [_spans addObject:child];
    }
    
    return child;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == spanTimestampObserver) {
        SentrySpan* finishedSpan = object;
        if (finishedSpan.timestamp != nil) {
            [finishedSpan removeObserver:self
                              forKeyPath:@"timestamp"
                                 context:&spanTimestampObserver];
            [self canBeFinished];
        }
    }
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
    [self finishWithStatus:kSentrySpanStatusUndefined];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    _shouldBeFinished = true;
    _finishStatus = status;
    [self canBeFinished];
}

- (BOOL)hasUnfinishedChildren
{
    @synchronized(_spans) {
        for (id<SentrySpan> span in _spans) {
            if (![span isFinished])
                return YES;
        }
        return NO;
    }
}

- (void)canBeFinished
{
    if (!_shouldBeFinished || (_waitForChildren && [self hasUnfinishedChildren]))
        return;

    [_rootSpan finishWithStatus:_finishStatus];
    [self captureTransaction];
}

- (NSArray<id<SentrySpan>> *)spans
{
    return _spans;
}

- (void)captureTransaction
{
    if (_hub == nil) return;

    [_hub captureEvent:[self toTransaction] withScope:_hub.scope];

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];
}

- (SentryTransaction*)toTransaction
{
    NSArray<id<SentrySpan>> *spans;
    @synchronized (_spans) {
        spans = [_spans
                 filteredArrayUsingPredicate:[NSPredicate
                                              predicateWithBlock:^BOOL(id<SentrySpan> _Nullable span,
                                                                       NSDictionary<NSString *, id> *_Nullable bindings) {
            return span.isFinished;
        }]];
    }
    
    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.name;
    return transaction;
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
