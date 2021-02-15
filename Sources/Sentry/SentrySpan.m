#import "SentrySpan.h"
#import "NSDate+SentryExtras.h"
#import "SentryCurrentDate.h"
#import "SentryTracer.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpan ()

@property (nonatomic) SentryTracer *tracer;

@end

@implementation SentrySpan {
    NSMutableDictionary<NSString *, id> *_extras;
}

- (instancetype)initWithTracer:(SentryTracer *)tracer
                          name:(NSString *)name
                       context:(SentrySpanContext *)context
{
    if ([self initWithName:name context:context]) {
        self.tracer = tracer;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name context:(SentrySpanContext *)context
{
    if ([super init]) {
        self.name = name;
        _context = context;
        self.startTimestamp = [SentryCurrentDate date];
        _extras = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id<SentrySpan>)startChildWithName:(NSString *)name operation:(NSString *)operation
{
    return [self startChildWithName:name operation:operation description:nil];
}

- (id<SentrySpan>)startChildWithName:(NSString *)name
                           operation:(NSString *)operation
                         description:(nullable NSString *)description
{
    return [self.tracer startChildWithParentId:[self.context spanId]
                                          name:name
                                     operation:operation
                                   description:description];
}

- (SentryId *)traceId
{
    return _context.traceId;
}

- (SentrySpanId *)spanId
{
    return _context.spanId;
}

- (void)setDataValue:(nullable NSString *)value forKey:(NSString *)key
{
    @synchronized(_extras) {
        [_extras setValue:value forKey:key];
    }
}

- (nullable NSDictionary<NSString *, id> *)data
{
    return _extras;
}

- (BOOL)isFinished
{
    return self.timestamp != nil;
}

- (void)finish
{
    self.timestamp = [SentryCurrentDate date];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    self.context.status = status;
    [self finish];
}

- (NSDictionary *)serialize
{
    NSMutableDictionary<NSString *, id> *mutableDictionary =
        [[NSMutableDictionary alloc] initWithDictionary:[self.context serialize]];

    [mutableDictionary setValue:[self.timestamp sentry_toIso8601String] forKey:@"timestamp"];
    [mutableDictionary setValue:[self.startTimestamp sentry_toIso8601String]
                         forKey:@"start_timestamp"];

    if (_extras != nil) {
        @synchronized(_extras) {
            [mutableDictionary setValue:_extras.copy forKey:@"data"];
        }
    }

    return mutableDictionary;
}

@end

NS_ASSUME_NONNULL_END
