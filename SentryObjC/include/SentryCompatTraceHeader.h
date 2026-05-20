#import <Foundation/Foundation.h>
#import "SentryCompatSampleDecision.h"

@class SentryCompatId;
@class SentryCompatSpanId;

NS_ASSUME_NONNULL_BEGIN

/// W3C-style `sentry-trace` HTTP header.
@interface SentryCompatTraceHeader : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTraceId:(SentryCompatId *)traceId
                         spanId:(SentryCompatSpanId *)spanId
                        sampled:(SentryCompatSampleDecision)sampled;

@property (nonatomic, readonly, strong) SentryCompatId *traceId;
@property (nonatomic, readonly, strong) SentryCompatSpanId *spanId;
@property (nonatomic, readonly) SentryCompatSampleDecision sampled;

/// Value to use in the `sentry-trace` HTTP header.
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
