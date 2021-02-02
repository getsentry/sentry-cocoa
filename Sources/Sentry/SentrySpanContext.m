#import "SentrySpanContext.h"
#import "SentryId.h"
#import "SentrySpanId.h"

@implementation SentrySpanContext

- (instancetype)init
{
    return [self initWithSampled:false];
}

- (instancetype)initWithSampled:(BOOL)sampled
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                      andSampled:sampled];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(SentrySpanId *_Nullable)parentId
                     andSampled:(BOOL)sampled
{
    if (self = [super init]) {
        self.traceId = traceId;
        self.spanId = spanId;
        self.parentSpanId = parentId;
        self.sampled = sampled;
        self.status = kSentrySpanStatusUndefined;
        _tags = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (NSString *)type
{
    static NSString *type;
    if (type == nil)
        type = @"trace";
    return type;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *mutabledictionary = @{
        @"type" : SentrySpanContext.type,
        @"span_id" : self.spanId.sentrySpanIdString,
        @"trace_id" : self.traceId.sentryIdString,
        @"sampled" : self.sampled ? @"true" : @"false",
        @"tags" : _tags.copy
    }
                                                 .mutableCopy;

    if (self.operation != nil)
        [mutabledictionary setValue:self.operation forKey:@"op"];

    if (self.parentSpanId != nil)
        [mutabledictionary setValue:self.parentSpanId.sentrySpanIdString forKey:@"parent_span_id"];

    if (self.status != kSentrySpanStatusUndefined)
        [mutabledictionary setValue:SentrySpanStatusNames[self.status] forKey:@"status"];

    return mutabledictionary;
}
@end
