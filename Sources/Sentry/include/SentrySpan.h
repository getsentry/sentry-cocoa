#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer, SentryId, SentrySpanId, SentryTraceHeader;

@interface SentrySpan : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * An arbitrary mapping of additional metadata of the span.
 */
@property (readonly) NSDictionary<NSString *, id> *data;

/**
 * key-value pairs holding additional data about the span.
 */
@property (readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic) SentrySpanId *spanId;

/**
 * Id of a parent span.
 */
@property (nullable, nonatomic) SentrySpanId *parentSpanId;

/**
 * If trace is sampled.
 */
@property (nonatomic) SentrySampleDecision sampled;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nonatomic, copy) NSString *operation;

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
 * The timestamp of which the span ended.
 */
@property (nullable, nonatomic, strong) NSDate *timestamp;

/**
 * The start time of the span.
 */
@property (nullable, nonatomic, strong) NSDate *startTimestamp;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * The Transaction this span is associated with.
 */
@property (nullable, nonatomic, readonly, weak) SentryTracer *tracer;

/**
 * Init a SentrySpan with given transaction and context.
 *
 * @param transaction The @c SentryTracer managing the transaction this span is associated with.
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithTracer:(SentryTracer *)transaction context:(SentrySpanContext *)context;

- (void)setExtraValue:(nullable id)value
               forKey:(NSString *)key DEPRECATED_ATTRIBUTE NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Sets a value to data.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key NS_SWIFT_NAME(setData(value:key:));

/**
 * Starts a child span.
 *
 * @param operation Short code identifying the type of operation the span is measuring.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation
                            description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Finishes the span by setting the end time.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 *
 * @param status The status of this span
 *  */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

/**
 * Returns the trace information that could be sent as a sentry-trace header.
 *
 * @return SentryTraceHeader.
 */
- (SentryTraceHeader *)toTraceHeader;

/**
 * Sets a tag value.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

@end

NS_ASSUME_NONNULL_END
