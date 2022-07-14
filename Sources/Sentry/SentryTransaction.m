#import "SentryTransaction.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryEnvelopeItemType.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransaction ()

@property (nonatomic, strong) NSArray<id<SentrySpan>> *spans;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *measurements;

@end

@implementation SentryTransaction

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<id<SentrySpan>> *)children
{
    if (self = [super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        self.trace = trace;
        self.spans = children;
        self.type = SentryEnvelopeItemTypeTransaction;
        self.measurements = [NSMutableDictionary new];
    }
    return self;
}

- (void)setMeasurementValue:(id)value forKey:(NSString *)key
{
    self.measurements[key] = value;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];

    NSMutableArray *serializedSpans = [[NSMutableArray alloc] init];
    for (id<SentrySpan> span in self.spans) {
        [serializedSpans addObject:[span serialize]];
    }
    serializedData[@"spans"] = serializedSpans;

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }

    mutableContext[@"trace"] = [self.trace serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    NSMutableDictionary<NSString *, id> *traceTags =
        [[self.trace.tags sentry_sanitize] mutableCopy];
    [traceTags addEntriesFromDictionary:[self.trace.context.tags sentry_sanitize]];

    // Adding tags from Trace to serializedData dictionary
    if (serializedData[@"tags"] != nil &&
        [serializedData[@"tags"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        [tags addEntriesFromDictionary:serializedData[@"tags"]];
        [tags addEntriesFromDictionary:traceTags];
        serializedData[@"tags"] = tags;
    } else {
        serializedData[@"tags"] = traceTags;
    }

    NSDictionary<NSString *, id> *traceData = [self.trace.data sentry_sanitize];

    // Adding data from Trace to serializedData dictionary
    if (serializedData[@"extra"] != nil &&
        [serializedData[@"extra"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *extra = [NSMutableDictionary new];
        [extra addEntriesFromDictionary:serializedData[@"extra"]];
        [extra addEntriesFromDictionary:traceData];
        serializedData[@"extra"] = extra;
    } else {
        serializedData[@"extra"] = traceData;
    }

    if (self.measurements.count > 0) {
        serializedData[@"measurements"] = [self.measurements.copy sentry_sanitize];
    }

    return serializedData;
}
@end

NS_ASSUME_NONNULL_END
