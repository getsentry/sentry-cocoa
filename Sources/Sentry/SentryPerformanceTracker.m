#import "SentryPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"

static NSString *const SENTRY_PERFORMANCE_TRACKER_SPANS = @"SENTRY_PERFORMANCE_TRACKER_SPANS";
static NSString *const SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK
    = @"SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK";

/*
 * Auxiliary class to store tracking information.
 */
@interface SentrySpanTracker : NSObject

@property (nonatomic) id<SentrySpan> span;
@property (nonatomic) BOOL finished;
@property (nonatomic) SentrySpanStatus finishedStatus;
@property (nonatomic, strong) NSMutableDictionary<SentrySpanId *, SentrySpanTracker *> *children;

- (instancetype)initWithSpan:(id<SentrySpan>)span;
- (void)markFinishedWithStatus:(SentrySpanStatus)status;

@end

@implementation SentrySpanTracker

- (instancetype)initWithSpan:(id<SentrySpan>)span
{
    if (self = [super init]) {
        self.span = span;
        self.finished = false;
        self.children = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)markFinishedWithStatus:(SentrySpanStatus)status
{
    self.finishedStatus = status;
    self.finished = YES;
}
@end

@implementation SentryPerformanceTracker

+ (instancetype)shared
{
    static SentryPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

/**
 * A dictionary of created spans in this thread using id as Key.
 */
- (NSMutableDictionary *)spansForThread
{
    NSMutableDictionary *result =
        [NSThread.currentThread.threadDictionary objectForKey:SENTRY_PERFORMANCE_TRACKER_SPANS];
    if (result == nil) {
        result = [[NSMutableDictionary alloc] init];
        [NSThread.currentThread.threadDictionary setObject:result
                                                    forKey:SENTRY_PERFORMANCE_TRACKER_SPANS];
    }
    return result;
}

/**
 * A stack of active spans in this thread.
 */
- (NSMutableArray *)activeStackForThread
{
    NSMutableArray *res = [NSThread.currentThread.threadDictionary
        objectForKey:SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK];
    if (res == nil) {
        res = [[NSMutableArray alloc] init];
        [NSThread.currentThread.threadDictionary setObject:res
                                                    forKey:SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK];
    }
    return res;
}

- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation
{
    NSMutableDictionary *spans = [self spansForThread];
    NSMutableArray *activeStack = [self activeStackForThread];

    SentrySpanTracker *activeSpanTracker = [activeStack lastObject];
    SentrySpanTracker *newSpan;
    if (activeSpanTracker != nil) {
        newSpan = [[SentrySpanTracker alloc]
            initWithSpan:[activeSpanTracker.span startChildWithOperation:name]];
    } else {

        BOOL hasBindScope = SentrySDK.currentHub.scope != nil;

        newSpan = [[SentrySpanTracker alloc]
            initWithSpan:[SentrySDK startTransactionWithName:name
                                                   operation:operation
                                                 bindToScope:!hasBindScope]];
    }

    SentrySpanId *spanId = newSpan.span.context.spanId;
    activeSpanTracker.children[spanId] = newSpan;
    spans[spanId] = newSpan;

    return newSpan.span.context.spanId;
}

- (nullable SentrySpanId *)activeSpan
{
    NSMutableArray *activeStack = [self activeStackForThread];
    SentrySpanTracker *activeSpan = activeStack.lastObject;
    return activeSpan.span.context.spanId;
}

- (void)pushActiveSpan:(SentrySpanId *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    NSMutableArray *activeStack = [self activeStackForThread];

    SentrySpanTracker *toActiveSpan = spans[spanId];
    if (toActiveSpan != nil) {
        [activeStack addObject:toActiveSpan];
    }
}

- (void)popActiveSpan
{
    NSMutableArray *activeStack = [self activeStackForThread];
    [activeStack removeLastObject];
}

- (void)finishSpan:(SentrySpanId *)spanId
{
    [self finishSpan:spanId withStatus:-1];
}

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status
{
    NSMutableDictionary *spans = [self spansForThread];

    SentrySpanTracker *spanTracker = spans[spanId];
    [spanTracker markFinishedWithStatus:status];

    [self propagateFinishForSpan:spanId];
}

/**
 * Tries to finish a span if it is marked to be finished and has no children,
 * then if it has a parent span, remove it from the parent and checks if the parent needs to be
 * finished.
 */
- (void)propagateFinishForSpan:(SentrySpanId *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    SentrySpanTracker *spanTracker = spans[spanId];

    if (spanTracker.finished && spanTracker.children.count == 0) {
        spanTracker.finishedStatus != -1
            ? [spanTracker.span finishWithStatus:spanTracker.finishedStatus]
            : [spanTracker.span finish];

        if (spanTracker.span.context.parentSpanId != nil) {
            SentrySpanTracker *parent = spans[spanTracker.span.context.parentSpanId];
            [parent.children removeObjectForKey:spanId];
            [self propagateFinishForSpan:parent.span.context.spanId];
        }

        [spans removeObjectForKey:spanId];
    }
}

- (BOOL)isSpanAlive:(SentrySpanId *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    return spans[spanId] != nil;
}

@end
