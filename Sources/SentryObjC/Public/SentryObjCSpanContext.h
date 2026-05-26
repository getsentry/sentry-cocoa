#import "SentryObjCSampleDecision.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCSpanContext : NSObject

@property (nonatomic, readonly, strong) SentryObjCId *traceId;
@property (nonatomic, readonly, strong) SentryObjCSpanId *spanId;
@property (nonatomic, readonly, strong, nullable) SentryObjCSpanId *parentSpanId;
@property (nonatomic, readonly) SentryObjCSampleDecision sampled;
@property (nonatomic, readonly, copy) NSString *operation;
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;
@property (nonatomic, copy) NSString *origin;

- (instancetype)initWithOperation:(NSString *)operation;
- (instancetype)initWithOperation:(NSString *)operation sampled:(SentryObjCSampleDecision)sampled;
- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                       parentId:(nullable SentryObjCSpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentryObjCSampleDecision)sampled;
- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                       parentId:(nullable SentryObjCSpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentryObjCSampleDecision)sampled;

@end

NS_ASSUME_NONNULL_END
