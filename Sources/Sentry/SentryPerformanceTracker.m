#import "SentryPerformanceTracker.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"

static NSString *const SENTRY_PERFORMANCE_TRACKER_SPANS = @"SENTRY_PERFORMANCE_TRACKER_SPANS";
static NSString *const SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK
    = @"SENTRY_PERFORMANCE_TRACKER_ACTIVE_STACK";

@interface SentrySpanTracker : NSObject

@property (nonatomic) id<SentrySpan> span;
@property (nonatomic) BOOL finished;
@property (nonatomic) SentrySpanStatus finishedStatus;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SentrySpanTracker *> *children;

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

- (NSMutableDictionary *)spansForThread
{
    NSMutableDictionary *res =
        [NSThread.currentThread.threadDictionary objectForKey:SENTRY_PERFORMANCE_TRACKER_SPANS];
    if (res == nil) {
        res = [[NSMutableDictionary alloc] init];
        [NSThread.currentThread.threadDictionary setObject:res
                                                    forKey:SENTRY_PERFORMANCE_TRACKER_SPANS];
    }
    return res;
}

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

- (NSString *)startSpanWithName:(NSString *)name
{
    return [self startSpanWithName:name operation:nil];
}

- (NSString *)startSpanWithName:(NSString *)name operation:(nullable NSString *)operation
{
    NSMutableDictionary *spans = [self spansForThread];
    NSMutableArray *activeStack = [self activeStackForThread];

    SentrySpanTracker *activeSpanTracker = [activeStack lastObject];
    SentrySpanTracker *newSpan;
    if (activeSpanTracker != nil) {
        newSpan = [[SentrySpanTracker alloc]
            initWithSpan:[activeSpanTracker.span startChildWithOperation:name]];
    } else {
        BOOL hasBindScope = SentrySDK.currentHub.scope.span != nil;

        newSpan = [[SentrySpanTracker alloc]
            initWithSpan:[SentrySDK startTransactionWithName:name
                                                   operation:operation
                                                 bindToScope:!hasBindScope]];
    }

    NSString *spanId = newSpan.span.context.spanId.sentrySpanIdString;
    activeSpanTracker.children[spanId] = newSpan;
    spans[spanId] = newSpan;

    return newSpan.span.context.spanId.sentrySpanIdString;
}

- (NSString *)activeSpan
{
    NSMutableArray *activeStack = [self activeStackForThread];
    SentrySpanTracker *activeSpan = activeStack.lastObject;
    return activeSpan.span.context.spanId.sentrySpanIdString;
}

- (void)pushActiveSpan:(NSString *)spanId
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

- (void)finishSpan:(NSString *)spanId
{
    [self finishSpan:spanId withStatus:-1];
}

- (void)finishSpan:(NSString *)spanId withStatus:(SentrySpanStatus)status
{
    NSMutableDictionary *spans = [self spansForThread];

    SentrySpanTracker *spanTracker = spans[spanId];
    [spanTracker markFinishedWithStatus:status];

    [self propagateFinishForSpan:spanId];
}

- (void)propagateFinishForSpan:(NSString *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    SentrySpanTracker *spanTracker = spans[spanId];

    if (spanTracker.finished && spanTracker.children.count == 0) {
        spanTracker.finishedStatus != -1
            ? [spanTracker.span finishWithStatus:spanTracker.finishedStatus]
            : [spanTracker.span finish];

        if (spanTracker.span.context.parentSpanId != nil) {
            SentrySpanTracker *parent
                = spans[spanTracker.span.context.parentSpanId.sentrySpanIdString];
            [parent.children removeObjectForKey:spanId];
            [self propagateFinishForSpan:parent.span.context.spanId.sentrySpanIdString];
        }

        [spans removeObjectForKey:spanId];
    }
}

- (BOOL)isSpanAlive:(NSString *)spanId
{
    NSMutableDictionary *spans = [self spansForThread];
    return spans[spanId] != nil;
}

@end
