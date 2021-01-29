#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanStatus.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId, SentrySpanId;

NS_SWIFT_NAME(SpanContext)
@interface SentrySpanContext : NSObject <SentrySerializable>

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic, strong) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic, strong) SentrySpanId *spanId;

/**
 * Id of a parent span.
 */
@property (nonatomic, strong) SentrySpanId *_Nullable parentSpanId;

/**
 * If trace is sampled.
 */
@property (nonatomic) BOOL sampled;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nonatomic, copy) NSString *_Nullable operation;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nonatomic, copy) NSString *_Nullable spanDescription;

/**
 * Describes the status of the Transaction.
 */
@property (nonatomic) SentrySpanStatus status;

/**
 * A map or list of tags for this event. Each tag must be less than 200 characters.
 */
@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *tags;

/**
 * Init a SentryContext and sets all fields by default.
 * @return SentryContext
 */
- (instancetype)init;

/**
 * Init a SentryContext and mark it as sampled or not, sets the other fields by default.
 * @param sampled Determines whether the trace is sampled
 * @return SentryContext
 */

- (instancetype)initWithSampled:(BOOL)sampled;

/**
 * Init a SentryContext with given traceId, spanId and parentId.
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentId Parent n id
 * @return SentryContext
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(SentrySpanId * _Nullable)parentId
                     andSampled:(BOOL)sampled;

+ (NSString *)type;

@end

NS_ASSUME_NONNULL_END
