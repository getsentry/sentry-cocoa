#import "SentryDefines.h"

@class SentryId, SentrySpanId, SentryTraceContext, SentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryPropagationContext : SENTRY_BASE_OBJECT

@property (nonatomic, strong) SentryId *traceId;
@property (nonatomic, strong) SentrySpanId *spanId;
@property (nonatomic, readonly) SentryTraceHeader *traceHeader;

- (NSDictionary<NSString *, NSString *> *)traceContextForEvent;

@end

NS_ASSUME_NONNULL_END
