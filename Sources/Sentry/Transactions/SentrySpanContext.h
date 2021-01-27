#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId, SentrySpanId;

NS_SWIFT_NAME(SpanContext)
@interface SentrySpanContext : NSObject

@property (nonatomic, strong) SentryId *traceId;

@property (nonatomic, strong) SentrySpanId *spanId;

@property (nonatomic, strong) SentrySpanId *_Nullable parentSpanId;

@property (nonatomic) BOOL sampled;

@property (nonatomic, copy) NSString *_Nullable operation;

@property (nonatomic, copy) NSString *_Nullable spanDescription;

@property (nonatomic, copy) NSString *_Nullable status;

@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *tags;

- (instancetype)init;
- (instancetype)initWithSampled:(BOOL)sampled;
- (instancetype)initWithtraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanID
                       parentId:(SentrySpanId *_Nullable)parentId
                     andSampled:(BOOL)sampled;

@end

NS_ASSUME_NONNULL_END
