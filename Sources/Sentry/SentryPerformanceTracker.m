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

@interface
SentryPerformanceTracker ()

@property (nonatomic, strong) NSMutableDictionary<SentrySpanId *, SentryTracer *> *spans;

@property (nonatomic, strong) NSMutableArray<SentryTracer *> *activeStack;

@end

@implementation SentryPerformanceTracker

+ (instancetype)shared
{
    static SentryPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.spans = [[NSMutableDictionary alloc] init];
        self.activeStack = [[NSMutableArray alloc] init];
    }
    return self;
}

- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation
{
    SentryTracer *activeSpanTracker;
    @synchronized(self.activeStack) {
        activeSpanTracker = [self.activeStack lastObject];
    }

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

    @synchronized(self.spans) {
        self.spans[spanId] = newSpan;
    }

    return spanId;
}

- (void)measureSpanWithName:(NSString *)name
                  operation:(NSString *)operation
                    inBlock:(void (^)(void))block
{
    SentrySpanId *spanId = [self startSpanWithName:name operation:operation];
    [self pushActiveSpan:spanId];
    block();
    [self popActiveSpan];
    [self finishSpan:spanId];
}

- (nullable SentrySpanId *)activeSpan
{
    @synchronized(self.activeStack) {
        return [self.activeStack lastObject].context.spanId;
    }
}

- (void)pushActiveSpan:(SentrySpanId *)spanId
{
    SentryTracer *toActiveSpan;
    @synchronized(self.spans) {
        toActiveSpan = self.spans[spanId];
    }

    if (toActiveSpan != nil) {
        @synchronized(self.activeStack) {
            [self.activeStack addObject:toActiveSpan];
        }
    }
}

- (void)popActiveSpan
{
    @synchronized(self.activeStack) {
        [self.activeStack removeLastObject];
    }
}

- (void)finishSpan:(SentrySpanId *)spanId
{
    [self finishSpan:spanId withStatus:kSentrySpanStatusUndefined];
}

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status
{
    SentryTracer *spanTracker;
    @synchronized(self.spans) {
        spanTracker = self.spans[spanId];
        [self.spans removeObjectForKey:spanId];
    }

    [spanTracker finishWithStatus:status];
}

- (BOOL)isSpanAlive:(SentrySpanId *)spanId
{
    @synchronized(self.spans) {
        return self.spans[spanId] != nil;
    }
}

@end
