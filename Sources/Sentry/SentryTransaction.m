#import "SentryTransaction.h"
#import "SentryEnvelopeItemType.h"
#import "SentryMeasurementValue.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpan+Private.h"
#import "SentrySwift.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTransaction

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<id<SentrySpan>> *)children
{
    if (self = [super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        self.trace = trace;
        self.spans = children;
        self.type = SentryEnvelopeItemTypeTransaction;
    }
    return self;
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
    id contextsDict = serializedData[@"contexts"];
    if (contextsDict != nil && [contextsDict isKindOfClass:[NSDictionary class]]) {
        [mutableContext addEntriesFromDictionary:contextsDict];
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    NSMutableDictionary *profileContextData = [NSMutableDictionary dictionary];
    profileContextData[@"profiler_id"] = self.trace.profileSessionID;
    mutableContext[@"profile"] = profileContextData;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    mutableContext[@"trace"] = [self.trace serialize];

    [serializedData setValue:mutableContext forKey:@"contexts"];

    NSMutableDictionary<NSString *, id> *traceTags = [sentry_sanitize(self.trace.tags) mutableCopy];
    NSDictionary *_Nullable sanitizedTags = sentry_sanitize(self.trace.tags);
    if (sanitizedTags != nil) {
        [traceTags addEntriesFromDictionary:(NSDictionary *_Nonnull)sanitizedTags];
    }

    // Adding tags from Trace to serializedData dictionary
    if (serializedData[@"tags"] != nil &&
        [serializedData[@"tags"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        id tagsValue = serializedData[@"tags"];
        if (tagsValue != nil) {
            [tags addEntriesFromDictionary:tagsValue];
        }
        [tags addEntriesFromDictionary:traceTags];
        serializedData[@"tags"] = tags;
    } else {
        serializedData[@"tags"] = traceTags;
    }

    NSDictionary<NSString *, id> *traceData = sentry_sanitize(self.trace.data);

    // Adding data from Trace to serializedData dictionary
    if (serializedData[@"extra"] != nil &&
        [serializedData[@"extra"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *extra = [NSMutableDictionary new];
        id extraValue = serializedData[@"extra"];
        if (extraValue != nil) {
            [extra addEntriesFromDictionary:extraValue];
        }
        [extra addEntriesFromDictionary:traceData];
        serializedData[@"extra"] = extra;
    } else {
        serializedData[@"extra"] = traceData;
    }

    if (self.trace.measurements.count > 0) {
        NSMutableDictionary<NSString *, id> *measurements = [NSMutableDictionary dictionary];

        for (NSString *measurementName in self.trace.measurements.allKeys) {
            measurements[measurementName] = [self.trace.measurements[measurementName] serialize];
        }

        serializedData[@"measurements"] = measurements;
    }

    if (self.trace) {
        serializedData[@"transaction"] = self.trace.transactionContext.name;

        serializedData[@"transaction_info"] =
            @{ @"source" : [self stringForNameSource:self.trace.transactionContext.nameSource] };
    }

    return serializedData;
}

- (NSString *)stringForNameSource:(SentryTransactionNameSource)source
{
    switch (source) {
    case kSentryTransactionNameSourceCustom:
        return @"custom";
    case kSentryTransactionNameSourceUrl:
        return @"url";
    case kSentryTransactionNameSourceRoute:
        return @"route";
    case kSentryTransactionNameSourceView:
        return @"view";
    case kSentryTransactionNameSourceComponent:
        return @"component";
    case kSentryTransactionNameSourceTask:
        return @"task";
    }
}
@end

NS_ASSUME_NONNULL_END
