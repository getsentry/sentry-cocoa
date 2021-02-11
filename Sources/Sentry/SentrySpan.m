#import "NSDate+SentryExtras.h"
#import "SentryCurrentDate.h"
#import "SentryTransaction+Private.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpan () {
    NSMutableDictionary<NSString *, id> *_extras;
}

/**
 * The transaction associated with this span.
 */
@property (nonatomic) SentryTransaction *transaction;

@end

@implementation SentrySpan

- (instancetype)initWithTransaction:(SentryTransaction *)transaction
                          operation:(NSString *)operation
                            traceId:(SentryId *)traceId
                           parentId:(SentrySpanId *)parentId
{
    if ([super initWithTraceId:traceId
                        spanId:[[SentrySpanId alloc] init]
                      parentId:parentId
                     operation:operation
                       sampled:transaction.isSampled]) {
        self.transaction = transaction;
        self.startTimestamp = [SentryCurrentDate date];
        _extras = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
{
    return [self startChildWithOperation:operation description:nil];
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
                            description:(nullable NSString *)description
{
    return [self.transaction startChildWithParentId:[self spanId]
                                          operation:operation
                                        description:description];
}

- (void)setExtraValue:(nullable NSString *)value forKey:(NSString *)key
{
    @synchronized(_extras) {
        [_extras setValue:value forKey:key];
    }
}

- (nullable NSDictionary<NSString *, id> *)extras
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
    self.status = status;
    [self finish];
}

- (NSDictionary *)serialize
{
    NSMutableDictionary<NSString *, id> *mutableDictionary =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];
    [mutableDictionary setValue:[self.timestamp sentry_toIso8601String] forKey:@"timestamp"];
    [mutableDictionary setValue:[self.startTimestamp sentry_toIso8601String]
                         forKey:@"start_timestamp"];

    if (_extras != nil) {
        [mutableDictionary setValue:_extras.copy forKey:@"data"];
    }

    return mutableDictionary;
}

@end

NS_ASSUME_NONNULL_END
