#import <Foundation/Foundation.h>
#import "SOCSentrySampleDecision.h"

@class SOCSentryId;
@class SOCSentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/// W3C-style `sentry-trace` HTTP header.
@interface SOCSentryTraceHeader : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTraceId:(SOCSentryId *)traceId
                         spanId:(SOCSentrySpanId *)spanId
                        sampled:(SOCSentrySampleDecision)sampled;

@property (nonatomic, readonly, strong) SOCSentryId *traceId;
@property (nonatomic, readonly, strong) SOCSentrySpanId *spanId;
@property (nonatomic, readonly) SOCSentrySampleDecision sampled;

/// Value to use in the `sentry-trace` HTTP header.
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
