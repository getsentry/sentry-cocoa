#import "SentrySpanContext.h"
#import "SentryId.h"
#import "SentrySpanId.h"

@interface
SentrySpanContext () {
    NSMutableDictionary<NSString *, NSString *> *_tags;
}

@end

@implementation SentrySpanContext

- (instancetype)initWithOperation:(NSString *)operation
{
    return [self initWithOperation:operation sampled:false];
}

- (instancetype)initWithOperation:(NSString *)operation sampled:(BOOL)sampled
{
    return [self initWithTraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                       operation:operation
                         sampled:sampled];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(BOOL)sampled
{
    if (self = [super init]) {
        self.traceId = traceId;
        self.spanId = spanId;
        self.parentSpanId = parentId;
        self.sampled = sampled;
        self.operation = operation;
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

- (NSDictionary<NSString *, NSString *> *)tags
{
    @synchronized(_tags) {
        return _tags.copy;
    }
}
- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags setValue:value forKey:key];
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags removeObjectForKey:key];
    }
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
