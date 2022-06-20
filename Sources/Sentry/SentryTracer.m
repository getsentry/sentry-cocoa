#import "SentryTracer.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryAppStartMeasurement.h"
#import "SentryClient.h"
#import "SentryCurrentDate.h"
#import "SentryFramesTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTraceContext.h"
#import "SentryTransaction+Private.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <SentryDispatchQueueWrapper.h>
#import <SentryScreenFrames.h>
#import <SentrySpanOperations.h>

NS_ASSUME_NONNULL_BEGIN

static const void *spanTimestampObserver = &spanTimestampObserver;

/**
 * The maximum amount of seconds the app start measurement end time and the start time of the
 * transaction are allowed to be apart.
 */
static const NSTimeInterval SENTRY_APP_START_MEASUREMENT_DIFFERENCE = 5.0;
static const NSTimeInterval SENTRY_AUTO_TRANSACTION_MAX_DURATION = 500.0;

@interface
SentryTracer ()

@property (nonatomic, strong) SentrySpan *rootSpan;
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *children;
@property (nonatomic, strong) SentryHub *hub;
@property (nonatomic) SentrySpanStatus finishStatus;
@property (nonatomic) BOOL isWaitingForChildren;
@property (nonatomic) NSTimeInterval idleTimeout;
@property (nonatomic, nullable, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryTracer {
    BOOL _waitForChildren;
    SentryTraceContext *_traceContext;
    NSMutableDictionary<NSString *, id> *_tags;
    NSMutableDictionary<NSString *, id> *_data;
    dispatch_block_t _idleTimeoutBlock;

#if SENTRY_HAS_UIKIT
    BOOL _startTimeChanged;

    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
#endif
}

static NSObject *appStartMeasurementLock;
static BOOL appStartMeasurementRead;

#if SENTRY_TARGET_PROFILING_SUPPORTED
static SentryProfiler *_Nullable profiler;
static NSLock *profilerLock;
#endif

+ (void)initialize
{
    if (self == [SentryTracer class]) {
        appStartMeasurementLock = [[NSObject alloc] init];
        appStartMeasurementRead = NO;
#if SENTRY_TARGET_PROFILING_SUPPORTED
        profilerLock = [[NSLock alloc] init];
#endif
    }
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
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                            waitForChildren:waitForChildren
                                idleTimeout:0.0
                       dispatchQueueWrapper:nil];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                               idleTimeout:(NSTimeInterval)idleTimeout
                      dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                            waitForChildren:YES
                                idleTimeout:idleTimeout
                       dispatchQueueWrapper:dispatchQueueWrapper];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                           waitForChildren:(BOOL)waitForChildren
                               idleTimeout:(NSTimeInterval)idleTimeout
                      dispatchQueueWrapper:
                          (nullable SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.rootSpan = [[SentrySpan alloc] initWithTransaction:self context:transactionContext];
        self.name = transactionContext.name;
        self.children = [[NSMutableArray alloc] init];
        self.hub = hub;
        self.isWaitingForChildren = NO;
        _waitForChildren = waitForChildren;
        _tags = [[NSMutableDictionary alloc] init];
        _data = [[NSMutableDictionary alloc] init];
        self.finishStatus = kSentrySpanStatusUndefined;
        self.idleTimeout = idleTimeout;
        self.dispatchQueueWrapper = dispatchQueueWrapper;

        if ([self hasIdleTimeout]) {
            [self dispatchIdleTimeout];
        }

#if SENTRY_HAS_UIKIT
        _startTimeChanged = NO;

        // Store current amount of frames at the beginning to be able to calculate the amount of
        // frames at the end of the transaction.
        SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
        if (framesTracker.isRunning) {
            SentryScreenFrames *currentFrames = framesTracker.currentFrames;
            initTotalFrames = currentFrames.total;
            initSlowFrames = currentFrames.slow;
            initFrozenFrames = currentFrames.frozen;
        }
#endif
#if SENTRY_TARGET_PROFILING_SUPPORTED
        if ([_hub getClient].options.enableProfiling) {
            [profilerLock lock];
            if (profiler == nil) {
                profiler = [[SentryProfiler alloc] init];
                [SentryLog logWithMessage:@"Starting profiler." andLevel:kSentryLevelDebug];
                [profiler start];
            }
            [profilerLock unlock];
        }
#endif
    }

    return self;
}

- (void)dispatchIdleTimeout
{
    dispatch_time_t now = [SentryCurrentDate dispatchTimeNow];
    dispatch_time_t delta = (int64_t)(self.idleTimeout * NSEC_PER_SEC);
    dispatch_time_t when = dispatch_time(now, delta);

    if (_idleTimeoutBlock != nil) {
        [self.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
    }
    __block SentryTracer *_self = self;
    _idleTimeoutBlock = dispatch_block_create(0, ^{ [_self finishInternal]; });
    [self.dispatchQueueWrapper dispatchAfter:when block:_idleTimeoutBlock];
}

- (BOOL)hasIdleTimeout
{
    return self.idleTimeout > 0 && self.dispatchQueueWrapper != nil;
}

- (BOOL)isAutoGeneratedTransaction
{
    return self.waitForChildren || [self hasIdleTimeout];
}

- (void)cancelIdleTimeout
{
    if ([self hasIdleTimeout]) {
        [self.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
    }
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
    [self cancelIdleTimeout];

    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:_rootSpan.context.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                           sampled:_rootSpan.context.sampled];
    context.spanDescription = description;

    SentrySpan *child = [[SentrySpan alloc] initWithTransaction:self context:context];
    @synchronized(self.children) {
        [_children addObject:child];
    }

    return child;
}

- (void)spanFinished:(id<SentrySpan>)finishedSpan
{
    // Calling canBeFinished on the rootSpan would end up in an endless loop because canBeFinished
    // calls finish on the rootSpan.
    if (finishedSpan != self.rootSpan) {
        [self canBeFinished];
    }
}

- (SentrySpanContext *)context
{
    return self.rootSpan.context;
}

- (nullable NSDate *)timestamp
{
    return self.rootSpan.timestamp;
}

- (void)setTimestamp:(nullable NSDate *)timestamp
{
    self.rootSpan.timestamp = timestamp;
}

- (nullable NSDate *)startTimestamp
{
    return self.rootSpan.startTimestamp;
}

- (SentryTraceContext *)traceContext
{
    if (_traceContext == nil) {
        @synchronized(self) {
            if (_traceContext == nil) {
                _traceContext = [[SentryTraceContext alloc] initWithTracer:self
                                                                     scope:_hub.scope
                                                                   options:SentrySDK.options];
            }
        }
    }
    return _traceContext;
}

- (void)setStartTimestamp:(nullable NSDate *)startTimestamp
{
    self.rootSpan.startTimestamp = startTimestamp;

#if SENTRY_HAS_UIKIT
    _startTimeChanged = YES;
#endif
}

- (nullable NSDictionary<NSString *, id> *)data
{
    @synchronized(_data) {
        return [_data copy];
    }
}

- (NSDictionary<NSString *, id> *)tags
{
    @synchronized(_tags) {
        return [_tags copy];
    }
}

- (BOOL)isFinished
{
    return self.rootSpan.isFinished;
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
    @synchronized(_data) {
        [_data setValue:value forKey:key];
    }
}

- (void)setExtraValue:(nullable id)value forKey:(NSString *)key
{
    [self setDataValue:value forKey:key];
}

- (void)removeDataForKey:(NSString *)key
{
    @synchronized(_data) {
        [_data removeObjectForKey:key];
    }
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags setValue:value forKey:key];
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags removeObjectForKey:key];
    }
}

- (SentryTraceHeader *)toTraceHeader
{
    return [self.rootSpan toTraceHeader];
}

- (void)finish
{
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    self.isWaitingForChildren = YES;
    _finishStatus = status;

    [self cancelIdleTimeout];
    [self canBeFinished];
}

- (void)canBeFinished
{
    // Transaction already finished and captured.
    // Sending another transaction and spans with
    // the same SentryId would be an error.
    if (self.rootSpan.isFinished)
        return;

    BOOL hasChildrenToWaitFor = [self hasChildrenToWaitFor];
    if (self.isWaitingForChildren == NO && !hasChildrenToWaitFor && [self hasIdleTimeout]) {
        [self dispatchIdleTimeout];
        return;
    }

    if (!self.isWaitingForChildren || hasChildrenToWaitFor)
        return;

    [self finishInternal];
}

- (BOOL)hasChildrenToWaitFor
{
    if (!_waitForChildren) {
        return NO;
    }

    @synchronized(_children) {
        for (id<SentrySpan> span in _children) {
            if (![span isFinished])
                return YES;
        }
        return NO;
    }
}

- (void)finishInternal
{
    [_rootSpan finishWithStatus:_finishStatus];

    if (self.finishCallback) {
        self.finishCallback(self);

        // The callback will only be executed once. No need to keep the reference and we avoid
        // potential retain cycles.
        self.finishCallback = nil;
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if ([_hub getClient].options.enableProfiling) {
        [SentryLog logWithMessage:@"Stopping profiler." andLevel:kSentryLevelDebug];
        [profilerLock lock];
        [profiler stop];
        [profilerLock unlock];
    }
#endif

    if (_hub == nil)
        return;

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];

    @synchronized(_children) {
        if (self.idleTimeout > 0.0 && _children.count == 0) {
            return;
        }

        for (id<SentrySpan> span in _children) {
            if (!span.isFinished) {
                [span finishWithStatus:kSentrySpanStatusDeadlineExceeded];

                // Unfinished children should have the same
                // end timestamp as their parent transaction
                span.timestamp = self.timestamp;
            }
        }

        if ([self hasIdleTimeout]) {
            [self trimEndTimestamp];
        }
    }

    SentryTransaction *transaction = [self toTransaction];

    // Prewarming can execute code up to viewDidLoad of a UIViewController, and keep the app in the
    // background. This can lead to auto-generated transactions lasting for minutes or event hours.
    // Therefore, we drop transactions lasting longer than SENTRY_AUTO_TRANSACTION_MAX_DURATION.
    NSTimeInterval transactionDuration = [self.timestamp timeIntervalSinceDate:self.startTimestamp];
    if ([self isAutoGeneratedTransaction]
        && transactionDuration >= SENTRY_AUTO_TRANSACTION_MAX_DURATION) {
        NSString *message =
            [NSString stringWithFormat:@"Auto generated transaction exceeded the max duration of "
                                       @"%f seconds. Not capturing transaction.",
                      SENTRY_AUTO_TRANSACTION_MAX_DURATION];
        [SentryLog logWithMessage:message andLevel:kSentryLevelInfo];
        return;
    }

    NSMutableArray<SentryEnvelopeItem *> *additionalEnvelopeItems = [NSMutableArray array];
#if SENTRY_TARGET_PROFILING_SUPPORTED
    if ([_hub getClient].options.enableProfiling) {
        [profilerLock lock];
        if (profiler != nil) {
            SentryEnvelopeItem *profile = [profiler buildEnvelopeItemForTransaction:transaction];
            if (profile != nil) {
                [additionalEnvelopeItems addObject:profile];
            }
            profiler = nil;
        }
        [profilerLock unlock];
    }
#endif

    [_hub captureTransaction:transaction
                      withScope:_hub.scope
        additionalEnvelopeItems:additionalEnvelopeItems];
}

- (void)trimEndTimestamp
{
    NSDate *oldest = self.startTimestamp;

    for (id<SentrySpan> childSpan in _children) {
        if ([oldest compare:childSpan.timestamp] == NSOrderedAscending) {
            oldest = childSpan.timestamp;
        }
    }

    if (oldest) {
        self.timestamp = oldest;
    }
}

- (SentryTransaction *)toTransaction
{
    SentryAppStartMeasurement *appStartMeasurement = [self getAppStartMeasurement];

    NSArray<id<SentrySpan>> *appStartSpans = [self buildAppStartSpans:appStartMeasurement];

    NSArray<id<SentrySpan>> *spans;
    @synchronized(_children) {
        [_children addObjectsFromArray:appStartSpans];
        spans = [_children copy];
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
    if (![self.context.operation isEqualToString:SentrySpanOperationUILoad]) {
        return nil;
    }

    // Hybrid SDKs send the app start measurement themselves.
    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        return nil;
    }

    // Double-Checked Locking to avoid acquiring unnecessary locks.
    if (appStartMeasurementRead == YES) {
        return nil;
    }

    SentryAppStartMeasurement *measurement = nil;
    @synchronized(appStartMeasurementLock) {
        if (appStartMeasurementRead == YES) {
            return nil;
        }

        measurement = [SentrySDK getAppStartMeasurement];
        if (measurement == nil) {
            return nil;
        }

        appStartMeasurementRead = YES;
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
    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = @"app.start.cold";
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = @"Warm Start";
        break;
    default:
        return @[];
    }

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

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

        SentryScreenFrames *currentFrames = framesTracker.currentFrames;
        NSInteger totalFrames = currentFrames.total - initTotalFrames;
        NSInteger slowFrames = currentFrames.slow - initSlowFrames;
        NSInteger frozenFrames = currentFrames.frozen - initFrozenFrames;

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

    return [[SentrySpan alloc] initWithTransaction:self context:context];
}

- (NSDictionary *)serialize
{
    NSMutableDictionary<NSString *, id> *mutableDictionary =
        [[NSMutableDictionary alloc] initWithDictionary:[_rootSpan serialize]];

    @synchronized(_data) {
        if (_data.count > 0) {
            NSMutableDictionary *data = _data.mutableCopy;
            if (mutableDictionary[@"data"] != nil &&
                [mutableDictionary[@"data"] isKindOfClass:NSDictionary.class]) {
                [data addEntriesFromDictionary:mutableDictionary[@"data"]];
            }
            mutableDictionary[@"data"] = data;
        }
    }

    @synchronized(_tags) {
        if (_tags.count > 0) {
            NSMutableDictionary *tags = _tags.mutableCopy;
            if (mutableDictionary[@"tags"] != nil &&
                [mutableDictionary[@"tags"] isKindOfClass:NSDictionary.class]) {
                [tags addEntriesFromDictionary:mutableDictionary[@"tags"]];
            }
            mutableDictionary[@"tags"] = tags;
        }
    }

    return mutableDictionary;
}

/**
 * Internal. Only needed for testing.
 */
+ (void)resetAppStartMeasurmentRead
{
    @synchronized(appStartMeasurementLock) {
        appStartMeasurementRead = NO;
    }
}

+ (nullable SentryTracer *)getTracer:(id<SentrySpan>)span
{
    if (span == nil) {
        return nil;
    }

    if ([span isKindOfClass:[SentryTracer class]]) {
        return span;
    } else if ([span isKindOfClass:[SentrySpan class]]) {
        return [(SentrySpan *)span transaction];
    }
    return nil;
}

@end

NS_ASSUME_NONNULL_END
