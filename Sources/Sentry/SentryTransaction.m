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
 * This transaction span context
 */
@property (nonatomic, strong) SentrySpanContext *spanContext;

/**
 * A hub this transaction is attached to.
 */
@property (nonatomic, readonly) SentryHub *_Nullable hub;

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
    return [self initWithName:name spanContext:[[SentrySpanContext alloc] init] andHub:nil];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)context
                                    andHub:(SentryHub *)hub
{
    return [self initWithName:context.name spanContext:context andHub:hub];
}

- (instancetype)initWithName:(NSString *)name
                 spanContext:(nonnull SentrySpanContext *)spanContext
                      andHub:(SentryHub *)hub
{
    if ([self init]) {
        self.transaction = name;
        self.startTimestamp = [SentryCurrentDate date];
        _hub = hub;
        self.spanContext = spanContext;
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

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];
    serializedData[@"spans"] = @[];

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = [_spanContext serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    return serializedData;
}
@end
