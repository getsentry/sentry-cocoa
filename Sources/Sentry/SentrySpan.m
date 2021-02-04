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
                            traceId:(SentryId *)traceId
                        andParentId:(SentrySpanId *)parentId
{
    if ([super initWithTraceId:traceId
                        spanId:[[SentrySpanId alloc] init]
                      parentId:parentId
                    andSampled:transaction.isSampled]) {
        self.transaction = transaction;
        self.startTimestamp = [SentryCurrentDate date];
    }

    return self;
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
{
    return [self startChildWithOperation:operation andDescription:nil];
}

- (SentrySpan *)startChildWithOperation:(NSString *)operation
                         andDescription:(nullable NSString *)description
{
    return [self.transaction startChildWithParentId:[self spanId]
                                          operation:operation
                                     andDescription:description];
}

- (void)setExtra:(NSString *)extra withValue:(id)value
{
    if (_extras == nil)
        _extras = [[NSMutableDictionary alloc] init];

    @synchronized(_extras) {
        [_extras setValue:value forKey:extra];
    }
}

- (nullable NSDictionary<NSString *, id> *)extras
{
    return _extras;
}

- (bool)isFinished
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
