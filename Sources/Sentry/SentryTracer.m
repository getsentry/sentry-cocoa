#import "SentryTracer.h"
#import "SentryAppStartMeasurement.h"
#import "SentryFramesTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransaction+Private.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"

@implementation SentryTracer {
    SentrySpan *_rootSpan;
    NSMutableArray<id<SentrySpan>> *_spans;
    SentryHub *_hub;

#if SENTRY_HAS_UIKIT
    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
#endif
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
{
    if ([super init]) {
        _rootSpan = [[SentrySpan alloc] initWithTracer:self context:transactionContext];
        self.name = transactionContext.name;
        _spans = [[NSMutableArray alloc] init];
        _hub = hub;

#if SENTRY_HAS_UIKIT
        // Store current amount of frames at the beginning to be able to calculate the amount of
        // frames at the end of the transaction.
        SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
        initTotalFrames = framesTracker.currentTotalFrames;
        initSlowFrames = framesTracker.currentSlowFrames;
        initFrozenFrames = framesTracker.currentFrozenFrames;
#endif
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

    SentrySpan *span = [[SentrySpan alloc] initWithTracer:self context:context];
    @synchronized(_spans) {
        [_spans addObject:span];
    }
    return span;
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
        // Make a new array with all finished child spans because if any of the transactions
        // children is not finished the transaction is ignored by Sentry.
        spans = [_spans
            filteredArrayUsingPredicate:[NSPredicate
                                            predicateWithBlock:^BOOL(id<SentrySpan> _Nullable span,
                                                NSDictionary<NSString *, id> *_Nullable bindings) {
                                                return span.isFinished;
                                            }]];
    }

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.name;
    [self addMeasurements:transaction];

    [_hub captureEvent:transaction withScope:_hub.scope];

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];
}

- (void)addMeasurements:(SentryTransaction *)transaction
{
    SentryAppStartMeasurement *appStartMeasurement = nil;
    NSString *valueKey = @"value";

    // Double-Checked Locking to avoid acquiring unnecessary locks
    if (SentrySDK.appStartMeasurement != nil) {
        @synchronized(SentrySDK.appStartMeasurement) {
            if (SentrySDK.appStartMeasurement != nil) {
                appStartMeasurement = SentrySDK.appStartMeasurement;
                SentrySDK.appStartMeasurement = nil;
            }
        }
    }

    if (appStartMeasurement != nil) {
        NSString *type = nil;
        if ([appStartMeasurement.type isEqualToString:SentryAppStartTypeCold]) {
            type = @"app_start_cold";
        } else if ([appStartMeasurement.type isEqualToString:SentryAppStartTypeWarm]) {
            type = @"app_start_warm";
        }

        if (type != nil) {
            [transaction setMeasurementValue:@{ valueKey : @(appStartMeasurement.duration * 1000) }
                                      forKey:type];
        }
    }

#if SENTRY_HAS_UIKIT
    // Frames
    SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
    NSInteger totalFrames = framesTracker.currentTotalFrames - initTotalFrames;
    NSInteger slowFrames = framesTracker.currentSlowFrames - initSlowFrames;
    NSInteger frozenFrames = framesTracker.currentFrozenFrames - initFrozenFrames;

    [transaction setMeasurementValue:@{ valueKey : @(totalFrames) } forKey:@"frames_total"];
    [transaction setMeasurementValue:@{ valueKey : @(slowFrames) } forKey:@"frames_slow"];
    [transaction setMeasurementValue:@{ valueKey : @(frozenFrames) } forKey:@"frames_frozen"];
#endif
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
