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
#import "SentryUIViewControllerPerformanceTracker.h"

static const void *spanTimestampObserver = &spanTimestampObserver;

/**
 * The maximum amount of seconds the app start measurement end time and the start time of the
 * transaction are allowed to be apart.
 */
static const NSTimeInterval SENTRY_APP_START_MEASUREMENT_DIFFERENCE = 5.0;

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

#if SENTRY_HAS_UIKIT
    BOOL _startTimeChanged;

    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
#endif
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

#if SENTRY_HAS_UIKIT
        _startTimeChanged = NO;

        // Store current amount of frames at the beginning to be able to calculate the amount of
        // frames at the end of the transaction.
        SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
        if (framesTracker.isRunning) {
            initTotalFrames = framesTracker.currentTotalFrames;
            initSlowFrames = framesTracker.currentSlowFrames;
            initFrozenFrames = framesTracker.currentFrozenFrames;
        }
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

#if SENTRY_HAS_UIKIT
    _startTimeChanged = YES;
#endif
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

- (SentryTraceHeader *)toTraceHeader
{
    return [self.rootSpan toTraceHeader];
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
    SentryAppStartMeasurement *appStartMeasurement = [self getAppStartMeasurement];

    NSArray<id<SentrySpan>> *appStartSpans = [self buildAppStartSpans:appStartMeasurement];

    NSArray<id<SentrySpan>> *spans;
    @synchronized(_children) {

        [_children addObjectsFromArray:appStartSpans];

        spans = [_children
            filteredArrayUsingPredicate:[NSPredicate
                                            predicateWithBlock:^BOOL(id<SentrySpan> _Nullable span,
                                                NSDictionary<NSString *, id> *_Nullable bindings) {
                                                return span.isFinished;
                                            }]];
    }

    if (appStartMeasurement != nil) {
        [self setStartTimestamp:appStartMeasurement.appStartTimestamp];
    }

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.name;
    [self addMeasurements:transaction appStartMeasurement:appStartMeasurement];
    return transaction;
}

- (nullable SentryAppStartMeasurement *)getAppStartMeasurement
{
    // Only send app start measurement for transactions generated by auto performance
    // instrumentation.
    if (![self.context.operation isEqualToString:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION]) {
        return nil;
    }

    SentryAppStartMeasurement *measurement = [SentrySDK getAndResetAppStartMeasurement];
    if (measurement == nil) {
        return nil;
    }

    NSDate *appStartTimestamp = measurement.appStartTimestamp;
    NSDate *appStartEndTimestamp =
        [appStartTimestamp dateByAddingTimeInterval:measurement.duration];

    NSTimeInterval difference = [appStartEndTimestamp timeIntervalSinceDate:self.startTimestamp];

    // If the difference between the end of the app start and the beginning of the current
    // transaction is smaller than SENTRY_APP_START_MEASUREMENT_DIFFERENCE. With this we
    // avoid messing up transactions too much.
    if (difference > SENTRY_APP_START_MEASUREMENT_DIFFERENCE
        || difference < -SENTRY_APP_START_MEASUREMENT_DIFFERENCE) {
        return nil;
    }

    return measurement;
}

- (NSArray<SentrySpan *> *)buildAppStartSpans:
    (nullable SentryAppStartMeasurement *)appStartMeasurement
{
    if (appStartMeasurement == nil || appStartMeasurement.type == SentryAppStartTypeUnknown) {
        return @[];
    }

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    NSString *operation;
    NSString *type;

    if (appStartMeasurement.type == SentryAppStartTypeCold) {
        operation = @"app.start.cold";
        type = @"Cold Start";
    } else if (appStartMeasurement.type == SentryAppStartTypeWarm) {
        operation = @"app.start.warm";
        type = @"Warm Start";
    }

    SentrySpan *appStartSpan = [self buildSpan:_rootSpan.context.spanId
                                     operation:operation
                                   description:type];
    [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];

    SentrySpan *runtimeInitSpan = [self buildSpan:appStartSpan.context.spanId
                                        operation:operation
                                      description:@"Pre main"];
    [runtimeInitSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
    [runtimeInitSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];

    SentrySpan *appInitSpan = [self buildSpan:appStartSpan.context.spanId
                                    operation:operation
                                  description:@"UIKit and Application Init"];
    [appInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];

    SentrySpan *frameRenderSpan = [self buildSpan:appStartSpan.context.spanId
                                        operation:operation
                                      description:@"Initial Frame Render"];
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];

    [appStartSpan setTimestamp:appStartEndTimestamp];

    return @[ appStartSpan, runtimeInitSpan, appInitSpan, frameRenderSpan ];
}

- (void)addMeasurements:(SentryTransaction *)transaction
    appStartMeasurement:(nullable SentryAppStartMeasurement *)appStartMeasurement
{
    NSString *valueKey = @"value";

    if (appStartMeasurement != nil && appStartMeasurement.type != SentryAppStartTypeUnknown) {
        NSString *type = nil;
        if (appStartMeasurement.type == SentryAppStartTypeCold) {
            type = @"app_start_cold";
        } else if (appStartMeasurement.type == SentryAppStartTypeWarm) {
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
    if (framesTracker.isRunning && !_startTimeChanged) {
        NSInteger totalFrames = framesTracker.currentTotalFrames - initTotalFrames;
        NSInteger slowFrames = framesTracker.currentSlowFrames - initSlowFrames;
        NSInteger frozenFrames = framesTracker.currentFrozenFrames - initFrozenFrames;

        BOOL allBiggerThanZero = totalFrames >= 0 && slowFrames >= 0 && frozenFrames >= 0;
        BOOL oneBiggerThanZero = totalFrames > 0 || slowFrames > 0 || frozenFrames > 0;

        if (allBiggerThanZero && oneBiggerThanZero) {
            [transaction setMeasurementValue:@{ valueKey : @(totalFrames) } forKey:@"frames_total"];
            [transaction setMeasurementValue:@{ valueKey : @(slowFrames) } forKey:@"frames_slow"];
            [transaction setMeasurementValue:@{ valueKey : @(frozenFrames) }
                                      forKey:@"frames_frozen"];

            NSString *message = [NSString
                stringWithFormat:@"Frames for transaction \"%@\" Total:%ld Slow:%ld Frozen:%ld",
                self.context.operation, (long)totalFrames, (long)slowFrames, (long)frozenFrames];
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        }
    }
#endif
}

- (id<SentrySpan>)buildSpan:(SentrySpanId *)parentId
                  operation:(NSString *)operation
                description:(NSString *)description
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:_rootSpan.context.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                           sampled:_rootSpan.context.sampled];
    context.spanDescription = description;

    return [[SentrySpan alloc] initWithContext:context];
}

- (NSDictionary *)serialize
{
    return [_rootSpan serialize];
}

@end
