#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

NS_SWIFT_NAME(SentryTransactionContext)
@interface SentryTransactionContext : SentrySpanContext

@property (nonatomic, readonly) NSString *name;
@property (nonatomic) bool parentSampled;

- (instancetype)init;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(SentrySpanId *)parentSpanId
            andParentSampled:(BOOL)parentSampled;

@end

NS_ASSUME_NONNULL_END
