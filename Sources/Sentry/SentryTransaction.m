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
SentryTransaction () {
    SentrySpanContext *trace;
}

/**
 * A hub this transaction is attached to.
 */
@property (nonatomic, readonly) SentryHub *_Nullable hub;

@end

@implementation SentryTransaction

- (NSDictionary<NSString *, id> *)serialize
{
    if (nil == self.timestamp) {
        self.timestamp = [SentryCurrentDate date];
    }

    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];
    serializedData[@"spans"] = @[];

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = @{
        @"name" : self.transaction,
        @"span_id" : trace.spanId.sentrySpanIdString,
        @"tags" : @ {},
        @"trace_id" : [[SentryId alloc] init].sentryIdString
    };
    [serializedData setValue:mutableContext forKey:@"contexts"];

    return serializedData;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.eventId = [[SentryId alloc] init];
        self.type = @"transaction";
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
        trace = spanContext;
    }
    return self;
}

- (void)finish
{
    self.timestamp = [SentryCurrentDate date];
    [self.hub captureTransaction:self];
}

@end
