#import <Foundation/Foundation.h>
#import "SentryCompatSampleDecision.h"

@class SentryCompatId;
@class SentryCompatSpanId;

NS_ASSUME_NONNULL_BEGIN

/// Read-only context describing a span's identity.
@interface SentryCompatSpanContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithOperation:(NSString *)operation;
- (instancetype)initWithOperation:(NSString *)operation
                          sampled:(SentryCompatSampleDecision)sampled;
- (instancetype)initWithTraceId:(SentryCompatId *)traceId
                         spanId:(SentryCompatSpanId *)spanId
                       parentId:(nullable SentryCompatSpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentryCompatSampleDecision)sampled;
- (instancetype)initWithTraceId:(SentryCompatId *)traceId
                         spanId:(SentryCompatSpanId *)spanId
                       parentId:(nullable SentryCompatSpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)spanDescription
                        sampled:(SentryCompatSampleDecision)sampled;

@property (nonatomic, readonly, strong) SentryCompatId *traceId;
@property (nonatomic, readonly, strong) SentryCompatSpanId *spanId;
@property (nonatomic, readonly, strong, nullable) SentryCompatSpanId *parentSpanId;
@property (nonatomic, readonly) SentryCompatSampleDecision sampled;
@property (nonatomic, readonly, copy) NSString *operation;
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;
@property (nonatomic, copy) NSString *origin;

@end

NS_ASSUME_NONNULL_END
