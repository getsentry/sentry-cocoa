#import "SentryTransaction.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryEnvelopeItemType.h"

@implementation SentryTransaction {
    id<SentrySpan> _trace;
    NSArray<id<SentrySpan>> *_spans;
    NSMutableDictionary<NSString *, id> *measurements;
}

- (instancetype)initWithTrace:(id<SentrySpan>)trace children:(NSArray<id<SentrySpan>> *)children
{
    if ([super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        _trace = trace;
        _spans = children;
        self.type = SentryEnvelopeItemTypeTransaction;
        measurements = [NSMutableDictionary new];
    }
    return self;
}

- (void)setMeasurementValue:(id)value forKey:(NSString *)key
{
    @synchronized(measurements) {
        measurements[key] = value;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];

    NSMutableArray *spans = [[NSMutableArray alloc] init];
    for (id<SentrySpan> span in _spans) {
        [spans addObject:[span serialize]];
    }
    serializedData[@"spans"] = spans;

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = [_trace serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    @synchronized(measurements) {
        if (measurements.count > 0) {
            serializedData[@"measurements"] = [measurements.copy sentry_sanitize];
        }
    }

    return serializedData;
}
@end
