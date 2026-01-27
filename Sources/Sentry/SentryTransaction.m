#import "SentryTransaction.h"
#import "SentryInternalDefines.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpanInternal+Private.h"
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
        self.type = SentryEnvelopeItemTypes.transaction;
    }
    return self;
}

- (nullable NSDictionary<NSString *, NSString *> *)tags
{
    if (self.trace == nil) {
        // Fallback to superclass if trace is nil (shouldn't happen for valid transactions)
        return [super tags];
    }

    // Merge event tags and tracer tags (tracer tags take precedence)
    NSDictionary<NSString *, NSString *> *eventTags = [super tags] ?: @{};
    NSDictionary<NSString *, NSString *> *tracerTags = self.trace.tags ?: @{};

    // Merge both, with tracer tags taking precedence
    // Note: We return a mutable dictionary copy (though declared as NSDictionary *).
    //
    // Swift behavior:
    //   When Swift code does: transaction.tags?["key"] = "value"
    //   Swift expands this to: get tags, modify copy, call setter with modified copy.
    //   So the setter IS called automatically, which is why modifications persist.
    //
    // Objective-C behavior:
    //   In Objective-C, modifying the returned dictionary directly does NOT persist:
    //     NSMutableDictionary *tags = transaction.tags;
    //     tags[@"key"] = @"value";  // Modifies local copy only!
    //   To persist changes in Objective-C, you must explicitly call the setter:
    //     transaction.tags = tags;  // Now changes persist
    NSMutableDictionary<NSString *, NSString *> *merged =
        [NSMutableDictionary dictionaryWithDictionary:eventTags];
    [merged addEntriesFromDictionary:tracerTags];
    return merged;
}

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags
{
    if (self.trace == nil) {
        // Fallback to superclass if trace is nil (shouldn't happen for valid transactions)
        [super setTags:tags];
        return;
    }

    // Remove all existing tags from the tracer
    NSDictionary<NSString *, NSString *> *currentTracerTags = self.trace.tags;
    for (NSString *key in currentTracerTags.allKeys) {
        [self.trace removeTagForKey:key];
    }

    // Clear event tags on the event
    [super setTags:nil];

    // Set all new tags on the tracer (transaction tags belong on tracer)
    if (tags != nil) {
        for (NSString *key in tags.allKeys) {
            NSString *value = tags[key];
            if (value != nil) {
                [self.trace setTagValue:value forKey:key];
            }
        }
    }
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
    if (serializedData[@"contexts"] != nil &&
        [serializedData[@"contexts"] isKindOfClass:NSDictionary.class]) {
        [mutableContext addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(
                                                     NSDictionary, serializedData[@"contexts"])];
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    NSMutableDictionary *profileContextData = [NSMutableDictionary dictionary];
    profileContextData[@"profiler_id"] = self.trace.profileSessionID;
    mutableContext[@"profile"] = profileContextData;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    mutableContext[@"trace"] = [self.trace serialize];

    [serializedData setValue:mutableContext forKey:@"contexts"];

    NSMutableDictionary<NSString *, id> *traceTags = [sentry_sanitize(self.trace.tags) mutableCopy];

    // Adding tags from Trace to serializedData dictionary
    if (serializedData[@"tags"] != nil &&
        [serializedData[@"tags"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        [tags
            addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, serializedData[@"tags"])];
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
        [extra addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(
                                            NSDictionary, serializedData[@"extra"])];
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
