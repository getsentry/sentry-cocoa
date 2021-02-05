#import "SentryTransaction.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryCurrentDate.h"
#import "SentryHub.h"
#import "SentryId.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransactionContext.h"

@interface

SentryTransaction ()

/**
 * This transaction span context.
 */
@property (nonatomic) SentrySpanContext *spanContext;

/**
 * A hub this transaction is attached to.
 */
@property (nullable, nonatomic) SentryHub *hub;

/**
 * A list of child spans.
 */
@property (nonatomic) NSMutableArray<SentrySpan *> *spans;

@end

@implementation SentryTransaction

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.eventId = [[SentryId alloc] init];
        self.type = @"transaction";
        self.spanContext = [[SentrySpanContext alloc] init];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
{
    return [self initWithName:name spanContext:[[SentrySpanContext alloc] init] hub:nil];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)context
                                       hub:(SentryHub *)hub
{
    return [self initWithName:context.name spanContext:context hub:hub];
}

- (instancetype)initWithName:(NSString *)name
                 spanContext:(nonnull SentrySpanContext *)spanContext
                         hub:(SentryHub *)hub
{
    if ([self init]) {
        self.transaction = name;
        self.startTimestamp = [SentryCurrentDate date];
        self.hub = hub;
        self.spanContext = spanContext;
        self.spans = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)finish
{
    self.timestamp = [SentryCurrentDate date];
    [self.hub captureTransaction:self];
}

- (SentrySpanId *)spanId
{
    return self.spanContext.spanId;
}

- (SentryId *)traceId
{
    return self.spanContext.traceId;
}

- (BOOL)isSampled
{
    return self.spanContext.sampled;
}

- (NSString *)spanDescription
{
    return self.spanContext.spanDescription;
}

- (void)setSpanDescription:(NSString *)spanDescription
{
    [_spanContext setSpanDescription:spanDescription];
}

- (SentrySpanStatus)status
{
    return self.spanContext.status;
}

- (void)setStatus:(SentrySpanStatus)status
{
    [self.spanContext setStatus:status];
}

- (NSString *)operation
{
    return self.spanContext.operation;
}

- (void)setOperation:(NSString *)operation
{
    [self.spanContext setOperation:operation];
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
{
    return [self startChildWithOperation:operation description:nil];
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
                         description:(nullable NSString *)description
{
    return [self startChildWithParentId:self.spanId operation:operation description:description];
}

- (SentrySpan *)startChildWithParentId:(SentrySpanId *)parentId
                             operation:(NSString *)operation
                        description:(nullable NSString *)description
{
    SentrySpan *span = [[SentrySpan alloc] initWithTransaction:self
                                                       traceId:self.traceId
                                                      parentId:parentId];
    span.operation = operation;
    span.spanDescription = description;
    span.sampled = self.isSampled;
    @synchronized(self.spans) {
        [self.spans addObject:span];
    }
    return span;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];

    NSMutableArray *spans = [[NSMutableArray alloc] init];
    for (SentrySpan *span in self.spans) {
        [spans addObject:[span serialize]];
    }
    serializedData[@"spans"] = spans;

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = [_spanContext serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    return serializedData;
}
@end
