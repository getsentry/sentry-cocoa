#import "SentryTracer.h"
#import "SentryAppStartMeasurement.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransaction+Private.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"

static const void *spanTimestampObserver = &spanTimestampObserver;

@implementation SentryTracer {
    SentrySpan *_rootSpan;
    NSMutableArray<id<SentrySpan>> *_children;
    SentryHub *_hub;
    SentrySpanStatus _finishStatus;
    BOOL _isFinished;
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
        _children = [[NSMutableArray alloc] init];
        _hub = hub;
        _isFinished = YES;
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

    if (_waitForChildren) {
        // Observe when the child finishes
        [child addObserver:self
                forKeyPath:NSStringFromSelector(@selector(timestamp))
                   options:NSKeyValueObservingOptionNew
                   context:&spanTimestampObserver];
    }

    @synchronized(_children) {
        [_children addObject:child];
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
    if (context == spanTimestampObserver &&
        [keyPath isEqualToString:NSStringFromSelector(@selector(timestamp))]) {
        SentrySpan *finishedSpan = object;
        if (finishedSpan.timestamp != nil) {
            [finishedSpan removeObserver:self
                              forKeyPath:NSStringFromSelector(@selector(timestamp))
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
    _isFinished = YES;
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
    if (!_isFinished || (_waitForChildren && [self hasUnfinishedChildren]))
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
    if (SentrySDK.appStartMeasurement != nil) {

        SentryAppStartMeasurement *appStartMeasurement = SentrySDK.appStartMeasurement;

        [self setStartTimestamp:appStartMeasurement.appStartTimestamp];
        NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
            dateByAddingTimeInterval:appStartMeasurement.duration];

        NSString *operation = @"app start";

        NSString *type;
        if (appStartMeasurement.type == SentryAppStartTypeCold) {
            type = @"Cold Start";
        } else if (appStartMeasurement.type == SentryAppStartTypeWarm) {
            type = @"Warm Start";
        }

        SentrySpan *appLaunch = [self measurement:_rootSpan.context.spanId
                                        operation:operation
                                      description:type];
        [appLaunch setStartTimestamp:appStartMeasurement.appStartTimestamp];

        SentrySpan *runtimeInitSpan = [self measurement:appLaunch.context.spanId
                                              operation:operation
                                            description:@"Pre main"];
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.runtimeInit];

        SentrySpan *appInitSpan = [self measurement:appLaunch.context.spanId
                                          operation:operation
                                        description:@"UIKit and Application Init"];
        [appInitSpan setStartTimestamp:appStartMeasurement.runtimeInit];
        [appInitSpan setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];

        SentrySpan *frameRenderSpan = [self measurement:appLaunch.context.spanId
                                              operation:operation
                                            description:@"Initial Frame Render"];
        [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
        [frameRenderSpan setTimestamp:appStartEndTimestamp];

        [appLaunch setTimestamp:appStartEndTimestamp];
    }

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
    [self addMeasurements:transaction];
    return transaction;
}

- (id<SentrySpan>)measurement:(SentrySpanId *)parentId
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

    [_children addObject:child];

    return child;
}

- (void)addMeasurements:(SentryTransaction *)transaction
{
    SentryAppStartMeasurement *appStartMeasurement = nil;

    // Double-Checked Locking to avoid acquiring unnecessary locks
    if (SentrySDK.appStartMeasurement != nil) {
        @synchronized(SentrySDK.appStartMeasurementLock) {
            if (SentrySDK.appStartMeasurement != nil) {
                appStartMeasurement = SentrySDK.appStartMeasurement;
                SentrySDK.appStartMeasurement = nil;
            }
        }
    }

    if (appStartMeasurement != nil) {
        NSString *type = nil;
        if (appStartMeasurement.type == SentryAppStartTypeCold) {
            type = @"app_start_cold";
        } else if (appStartMeasurement.type == SentryAppStartTypeWarm) {
            type = @"app_start_warm";
        }

        if (type != nil) {
            [transaction setMeasurementValue:@{ @"value" : @(appStartMeasurement.duration * 1000) }
                                      forKey:type];
        }
    }
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
