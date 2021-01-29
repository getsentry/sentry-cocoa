#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanStatus.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId, SentrySpanId;

NS_SWIFT_NAME(SentrySpanContext)
@interface SentrySpanContext : NSObject<SentrySerializable>

@property (nonatomic, strong) SentryId *traceId;

@property (nonatomic, strong) SentrySpanId *spanId;

@property (nonatomic, strong) SentrySpanId *_Nullable parentSpanId;

@property (nonatomic) BOOL sampled;

@property (nonatomic, copy) NSString * operation;

@property (nonatomic, copy) NSString *_Nullable spanDescription;

@property (nonatomic) SentrySpanStatus status;

@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *tags;

- (instancetype)init;
- (instancetype)initWithSampled:(BOOL)sampled;
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(SentrySpanId *_Nullable)parentId
                     andSampled:(BOOL)sampled;

+ (NSString *)type;

@end

NS_ASSUME_NONNULL_END
