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
@property (nullable, nonatomic, strong) SentrySpanId *parentSpanId;

/**
 * If trace is sampled.
 */
@property (nonatomic) BOOL sampled;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nullable, nonatomic, copy) NSString *operation;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nullable, nonatomic, copy) NSString *spanDescription;

/**
 * Describes the status of the Transaction.
 */
@property (nonatomic) SentrySpanStatus status;

/**
 * A map or list of tags for this event. Each tag must be less than 200 characters.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Init a SentryContext and sets all fields by default.
 *
 * @return SentryContext
 */
- (instancetype)init;

/**
 * Init a SentryContext and mark it as sampled or not, sets the other fields by default.
 *
 * @param sampled Determines whether the trace is sampled
 *
 * @return SentryContext
 */

- (instancetype)initWithSampled:(BOOL)sampled;

/**
 * Init a SentryContext with given traceId, spanId and parentId.
 *
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id
 * @param parentId Id of a parent span.
 *
 * @return SentryContext
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                     andSampled:(BOOL)sampled;

/**
 * Sets a tag with given value.
 */
- (void) setTag:(NSString *)tag withValue:(NSString *)value;

/**
 * Removes a tag.
 */
- (void) unsetTag:(NSString *)tag;


@property (class, nonatomic, readonly, copy) NSString *type;

@end

NS_ASSUME_NONNULL_END
