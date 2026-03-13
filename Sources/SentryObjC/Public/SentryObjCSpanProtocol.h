#import <Foundation/Foundation.h>

#import "SentryObjCSampleDecision.h"
#import "SentryObjCSerializable.h"
#import "SentryObjCSpanContext.h"
#import "SentryObjCSpanStatus.h"

@class SentryId;
@class SentryMeasurementUnit;
@class SentrySpanId;
@class SentryTraceContext;
@class SentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for a span in a trace.
 *
 * Spans represent units of work within a transaction, such as database queries,
 * network requests, or function calls. Use spans to instrument your code for
 * performance monitoring.
 *
 * @see SentrySDK
 * @see SentryTransactionContext
 */
@protocol SentrySpan <SentrySerializable>

/**
 * Unique identifier for the trace this span belongs to.
 *
 * All spans in the same trace share this ID.
 */
@property (nonatomic, strong) SentryId *traceId;

/**
 * Unique identifier for this span.
 */
@property (nonatomic, strong) SentrySpanId *spanId;

/**
 * Identifier of the parent span.
 *
 * @c nil for root spans (transactions).
 */
@property (nullable, nonatomic, strong) SentrySpanId *parentSpanId;

/**
 * Whether this span is sampled.
 *
 * Only sampled spans are sent to Sentry.
 */
@property (nonatomic) SentrySampleDecision sampled;

/**
 * Operation type for this span.
 *
 * Examples: "db.query", "http.client", "ui.load".
 */
@property (nonatomic, copy) NSString *operation;

/**
 * Origin of this span, indicating which instrumentation created it.
 *
 * Examples: "manual", "auto.http", "auto.db".
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Human-readable description of this span.
 *
 * Example: "SELECT * FROM users WHERE id = ?".
 */
@property (nullable, nonatomic, copy) NSString *spanDescription;

/**
 * Status of this span.
 *
 * Indicates whether the operation succeeded, failed, or was cancelled.
 */
@property (nonatomic) SentrySpanStatus status;

/**
 * Timestamp when this span finished.
 *
 * Set automatically when @c -finish is called.
 */
@property (nullable, nonatomic, strong) NSDate *timestamp;

/**
 * Timestamp when this span started.
 *
 * Set automatically when the span is created.
 */
@property (nullable, nonatomic, strong) NSDate *startTimestamp;

/**
 * Additional structured data attached to this span.
 *
 * Read-only. Use @c -setDataValue:forKey: to modify.
 */
@property (readonly) NSDictionary<NSString *, id> *data;

/**
 * Tags attached to this span.
 *
 * Read-only. Use @c -setTagValue:forKey: to modify.
 */
@property (readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Whether this span has been finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Trace context for distributed tracing.
 *
 * Contains information needed to continue the trace across service boundaries.
 */
@property (nullable, nonatomic, readonly) SentryTraceContext *traceContext;

/**
 * Starts a new child span with the specified operation.
 *
 * @param operation The operation type for the child span.
 * @return A new child span.
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation;

/**
 * Starts a new child span with operation and description.
 *
 * @param operation The operation type for the child span.
 * @param description Human-readable description of the operation.
 * @return A new child span.
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description;

/**
 * Sets a data value for the specified key.
 *
 * @param value The value to set, or @c nil to remove the key.
 * @param key The key to set.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key;

/**
 * Removes data for the specified key.
 *
 * @param key The key to remove.
 */
- (void)removeDataForKey:(NSString *)key;

/**
 * Sets a tag value for the specified key.
 *
 * @param value The tag value.
 * @param key The tag key.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;

/**
 * Removes a tag for the specified key.
 *
 * @param key The tag key to remove.
 */
- (void)removeTagForKey:(NSString *)key;

/**
 * Adds a measurement to this span.
 *
 * @param name The measurement name.
 * @param value The measurement value.
 */
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value;

/**
 * Adds a measurement with a unit to this span.
 *
 * @param name The measurement name.
 * @param value The measurement value.
 * @param unit The measurement unit.
 */
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit;

/**
 * Finishes this span with a successful status.
 *
 * Records the finish timestamp and marks the span as complete.
 */
- (void)finish;

/**
 * Finishes this span with the specified status.
 *
 * @param status The status to set for this span.
 */
- (void)finishWithStatus:(SentrySpanStatus)status;

/**
 * Creates a trace header for distributed tracing.
 *
 * @return A trace header containing this span's trace information.
 */
- (SentryTraceHeader *)toTraceHeader;

/**
 * Creates a baggage HTTP header value for distributed tracing.
 *
 * @return The baggage header value, or @c nil if no baggage is set.
 */
- (nullable NSString *)baggageHttpHeader;

/**
 * Serializes the span to a dictionary.
 *
 * @return Dictionary representation of the span.
 */
- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
