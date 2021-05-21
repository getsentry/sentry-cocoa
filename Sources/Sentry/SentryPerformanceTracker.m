#import "SentryPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"

static NSString *const SENTRY_PERFORMANCE_TRACKER_SPANS = @"SENTRY_PERFORMANCE_TRACKER_SPANS";
static NSString *const SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK
    = @"SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK";

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
- (NSMutableDictionary<SentrySpanId *, SentryTracer *> *)spansForThread
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
- (NSMutableArray<SentryTracer *> *)activeStackForThread
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

    SentryTracer *activeSpanTracker = [activeStack lastObject];
    SentryTracer *newSpan;
    if (activeSpanTracker != nil) {
        newSpan = [activeSpanTracker startChildWithOperation:name];
    } else {
        newSpan = [[SentryTracer alloc]
            initWithTransactionContext:[[SentryTransactionContext alloc] initWithName:name
                                                                            operation:operation]
                                   hub:SentrySDK.currentHub
                       waitForChildren:YES];

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
            if (span == nil) {
                [SentrySDK.currentHub.scope setSpan:newSpan];
            }
        }];
    }

    SentrySpanId *spanId = newSpan.context.spanId;
    spans[spanId] = newSpan;

    return newSpan.context.spanId;
}

- (void)measureSpanWithName:(NSString *)name
                  operation:(NSString *)operation
                    inBlock:(void (^)(void))block
{
    SentrySpanId *spanId = [self startSpanWithName:name operation:operation];
    block();
    [self finishSpan:spanId];
}

- (nullable SentrySpanId *)activeSpan
{
    NSMutableArray *activeStack = [self activeStackForThread];
    SentryTracer *activeSpan = activeStack.lastObject;
    return activeSpan.context.spanId;
}

- (void)pushActiveSpan:(SentrySpanId *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    NSMutableArray *activeStack = [self activeStackForThread];

    SentryTracer *toActiveSpan = spans[spanId];
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
    [self finishSpan:spanId withStatus:kSentrySpanStatusUndefined];
}

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status
{
    NSMutableDictionary *spans = [self spansForThread];

    SentryTracer *spanTracker = spans[spanId];
    [spanTracker finishWithStatus:status];
    [spans removeObjectForKey:spanId];
}

- (BOOL)isSpanAlive:(SentrySpanId *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    return spans[spanId] != nil;
}

@end
