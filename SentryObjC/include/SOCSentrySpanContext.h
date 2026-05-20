#import <Foundation/Foundation.h>
#import "SOCSentrySampleDecision.h"

@class SOCSentryId;
@class SOCSentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/// Read-only context describing a span's identity.
@interface SOCSentrySpanContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithOperation:(NSString *)operation;
- (instancetype)initWithOperation:(NSString *)operation
                          sampled:(SOCSentrySampleDecision)sampled;
- (instancetype)initWithTraceId:(SOCSentryId *)traceId
                         spanId:(SOCSentrySpanId *)spanId
                       parentId:(nullable SOCSentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SOCSentrySampleDecision)sampled;
- (instancetype)initWithTraceId:(SOCSentryId *)traceId
                         spanId:(SOCSentrySpanId *)spanId
                       parentId:(nullable SOCSentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)spanDescription
                        sampled:(SOCSentrySampleDecision)sampled;

@property (nonatomic, readonly, strong) SOCSentryId *traceId;
@property (nonatomic, readonly, strong) SOCSentrySpanId *spanId;
@property (nonatomic, readonly, strong, nullable) SOCSentrySpanId *parentSpanId;
@property (nonatomic, readonly) SOCSentrySampleDecision sampled;
@property (nonatomic, readonly, copy) NSString *operation;
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;
@property (nonatomic, copy) NSString *origin;

@end

NS_ASSUME_NONNULL_END
