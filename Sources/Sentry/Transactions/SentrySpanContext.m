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
    return [self initWithtraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                      andSampled:sampled];
}

- (instancetype)initWithtraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(SentrySpanId *_Nullable)parentId
                     andSampled:(BOOL)sampled
{
    if (self = [super init]) {
        self.traceId = traceId;
        self.spanId = spanId;
        self.parentSpanId = parentId;
        self.sampled = sampled;
    }
    return self;
}

@end
