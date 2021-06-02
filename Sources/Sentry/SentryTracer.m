#import "SentryTracer.h"
#import "SentryHub.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"

@interface
SentryTracer ()

@property (nonatomic, strong) SentrySpan *rootSpan;
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *children;
@property (nonatomic, strong) SentryHub *hub;
@property (nonatomic) SentrySpanStatus finishStatus;
@property (nonatomic) BOOL isWaitingForChildren;

@end

@implementation SentryTracer {
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
        self.rootSpan = [[SentrySpan alloc] initWithTracer:self context:transactionContext];
        self.name = transactionContext.name;
        self.children = [[NSMutableArray alloc] init];
        self.hub = hub;
        self.isWaitingForChildren = NO;
        _waitForChildren = waitForChildren;
        self.finishStatus = kSentrySpanStatusUndefined;
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

    if (_waitForChildren) {
        // Observe when the child finishes
        [child addObserver:self
                forKeyPath:NSStringFromSelector(@selector(timestamp))
                   options:NSKeyValueObservingOptionNew
                   context:nil];
    }

    @synchronized(self.children) {
        [self.children addObject:child];
    }

    return child;
}

/**
 * Is called when a span finishes and checks if we can finish.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(timestamp))]) {
        SentrySpan *finishedSpan = object;
        if (finishedSpan.timestamp != nil) {
            [finishedSpan removeObserver:self
                              forKeyPath:NSStringFromSelector(@selector(timestamp))
                                 context:nil];
            [self canBeFinished];
        }
    }
}

- (SentrySpanContext *)context
{
    return self.rootSpan.context;
}

- (NSDate *)timestamp
{
    return self.rootSpan.timestamp;
}

- (void)setTimestamp:(NSDate *)timestamp
{
    self.rootSpan.timestamp = timestamp;
}

- (NSDate *)startTimestamp
{
    return self.rootSpan.startTimestamp;
}

- (void)setStartTimestamp:(NSDate *)startTimestamp
{
    self.rootSpan.startTimestamp = startTimestamp;
}

- (NSDictionary<NSString *, id> *)data
{
    return self.rootSpan.data;
}

- (BOOL)isFinished
{
    return self.rootSpan.isFinished;
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
    [self.rootSpan setDataValue:value forKey:key];
}

- (void)finish
{
    [self finishWithStatus:kSentrySpanStatusUndefined];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    self.isWaitingForChildren = YES;
    _finishStatus = status;
    [self canBeFinished];
}

- (BOOL)hasUnfinishedChildren
{
    @synchronized(_children) {
        for (id<SentrySpan> span in _children) {
            if (![span isFinished])
                return YES;
        }
        return NO;
    }
}

- (void)canBeFinished
{
    if (!self.isWaitingForChildren || (_waitForChildren && [self hasUnfinishedChildren]))
        return;

    [_rootSpan finishWithStatus:_finishStatus];
    [self captureTransaction];
}

- (void)captureTransaction
{
    if (_hub == nil)
        return;

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];

    [_hub captureEvent:[self toTransaction] withScope:_hub.scope];
}

- (SentryTransaction *)toTransaction
{
    NSArray<id<SentrySpan>> *spans;
    @synchronized(_children) {
        spans = [_children
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
