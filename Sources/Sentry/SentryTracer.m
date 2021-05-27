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

/**
 * Perform a check whether this trace can be finished, if so, finishes the trace.
 *
 * The tracer can be finished when _waitForChildren is NO or all children are finished and the
 * finish function was called at least once.
 */
- (void)canBeFinished;

/**
 * Returns a flat list of all children recursively.
 */
- (NSArray<id<SentrySpan>> *)children;

/**
 * A lock to coordinate child manipulation.
 */
- (NSObject *)childrenLock;

/**
 * List of children. For testing purpose.
 */
- (NSArray<id<SentrySpan>> *)spans;

@end

@implementation SentryTracer {
    SentrySpan *_rootSpan;
    NSMutableArray<id<SentrySpan>> *_spans;
    SentryHub *_hub;
    SentrySpanStatus _finishStatus;
    BOOL _shouldBeFinished;
    BOOL _waitForChildren;
    SentryTracer *_parentTracer;
    NSObject *_childrenLock;
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
        _childrenLock = [[NSObject alloc] init];
    }

    return self;
}

- (instancetype)initWithParentTracer:(SentryTracer *)parent context:(SentrySpanContext *)context
{
    if ([super init]) {
        _rootSpan = [[SentrySpan alloc] initWithTracer:self context:context];
        _parentTracer = parent;
        _waitForChildren = parent.waitForChildren;
        _spans = [[NSMutableArray alloc] init];
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

    SentryTracer *child = [[SentryTracer alloc] initWithParentTracer:self context:context];
    @synchronized([self childrenLock]) {
        [_spans addObject:child];
    }
    return child;
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

- (NSObject *)childrenLock
{
    return _parentTracer == nil ? _childrenLock : [_parentTracer childrenLock];
}

- (BOOL)hasUnfinishedChildren
{
    @synchronized([self childrenLock]) {
        for (id<SentrySpan> span in _spans) {
            if (![span isFinished])
                return YES;
        }
        return NO;
    }
}

- (void)canBeFinished
{
    if (_waitForChildren && (!_shouldBeFinished || [self hasUnfinishedChildren]))
        return;

    [_rootSpan finishWithStatus:_finishStatus];
    if (_parentTracer == nil) {
        [self captureTransaction];
    } else {
        [_parentTracer canBeFinished];
    }
}

- (NSArray<id<SentrySpan>> *)children
{
    NSMutableArray<id<SentrySpan>> *result = [[NSMutableArray alloc] init];
    @synchronized([self childrenLock]) {
        for (id<SentrySpan> child in _spans) {
            [result addObject:child];
            if ([child isKindOfClass:[SentryTracer class]]) {
                SentryTracer *childTracer = child;
                [result addObjectsFromArray:[childTracer children]];
            }
        }
    }
    return result;
}

- (NSArray<id<SentrySpan>> *)spans
{
    return _spans;
}

- (void)captureTransaction
{
    if (_hub == nil)
        return;

    NSArray<id<SentrySpan>> *spans = [self.children
        filteredArrayUsingPredicate:[NSPredicate
                                        predicateWithBlock:^BOOL(id<SentrySpan> _Nullable span,
                                            NSDictionary<NSString *, id> *_Nullable bindings) {
                                            return span.isFinished;
                                        }]];

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.name;
    [_hub captureEvent:transaction withScope:_hub.scope];

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
