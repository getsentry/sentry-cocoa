#import "SentryObjCSampleDecision.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCTraceHeader : NSObject

@property (nonatomic, readonly, strong) SentryObjCId *traceId;
@property (nonatomic, readonly, strong) SentryObjCSpanId *spanId;
@property (nonatomic, readonly) SentryObjCSampleDecision sampled;

- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                        sampled:(SentryObjCSampleDecision)sampled;

- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
