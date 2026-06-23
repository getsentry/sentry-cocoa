#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#    import "SentryObjCSampleDecision.h"
#    import "SentryObjCSpanStatus.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#    import <SentryObjC/SentryObjCSampleDecision.h>
#    import <SentryObjC/SentryObjCSpanStatus.h>
#endif

@class SentryObjCId;
@class SentryObjCMeasurementUnit;
@class SentryObjCSpanId;
@class SentryObjCTraceContext;
@class SentryObjCTraceHeader;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a span in a distributed trace.
 * A span tracks a unit of work and can contain child spans.
 */
@interface SentryObjCSpan : NSObject
SENTRY_NO_INIT

/// Determines which trace the span belongs to.
@property (nonatomic, strong) SentryObjCId *traceId;

/// The span id.
@property (nonatomic, strong) SentryObjCSpanId *spanId;

/// The id of the parent span.
@property (nonatomic, strong, nullable) SentryObjCSpanId *parentSpanId;

/// The sampling decision of the trace.
@property (nonatomic) SentryObjCSampleDecision sampled;

/// Short code identifying the type of operation the span is measuring.
@property (nonatomic, copy) NSString *operation;

/**
 * The origin of the span indicates what created the span.
 * @note Gets set by the SDK. It is not expected to be set manually by users.
 * @see https://develop.sentry.dev/sdk/performance/trace-origin
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nonatomic, copy, nullable) NSString *spanDescription;

/// Describes the status of the span.
@property (nonatomic) SentryObjCSpanStatus status;

/// The timestamp at which the span ended.
@property (nonatomic, strong, nullable) NSDate *timestamp;

/// The start time of the span.
@property (nonatomic, strong, nullable) NSDate *startTimestamp;

/// An arbitrary mapping of additional metadata of the span.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *data;

/// Key-value pairs holding additional data about the span.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;

/// Whether the span is finished.
@property (nonatomic, readonly) BOOL isFinished;

/// Retrieves a trace context from this tracer.
@property (nonatomic, readonly, strong, nullable) SentryObjCTraceContext *traceContext;

/**
 * Starts a child span.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @return The child span.
 */
- (SentryObjCSpan *)startChildWithOperation:(NSString *)operation;

/**
 * Starts a child span.
 * @param operation Defines the child span operation.
 * @param description Defines the child span description.
 * @return The child span.
 */
- (SentryObjCSpan *)startChildWithOperation:(NSString *)operation
                                description:(nullable NSString *)description;

/**
 * Sets a value to the span's data dictionary.
 * @param value The value to set.
 * @param key The key for the data entry.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key;

/**
 * Removes a data value.
 * @param key The key of the data entry to remove.
 */
- (void)removeDataForKey:(NSString *)key;

/**
 * Adds a feature flag evaluation to this span.
 * @param name The feature flag name.
 * @param result The evaluated boolean result.
 */
- (void)addFeatureFlagWithName:(NSString *)name result:(BOOL)result;

/**
 * Removes a feature flag evaluation from this span.
 * @param name The feature flag name.
 */
- (void)removeFeatureFlagWithName:(NSString *)name;

/**
 * Sets a tag value.
 * @param value The tag value.
 * @param key The tag key.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;

/**
 * Removes a tag value.
 * @param key The tag key to remove.
 */
- (void)removeTagForKey:(NSString *)key;

/**
 * Set a measurement without unit. When setting the measurement without the unit, no formatting
 * will be applied to the measurement value in the Sentry product, and the value will be shown
 * as is.
 * @note Setting a measurement with the same name on the same transaction multiple times only
 * keeps the last value.
 * @param name The name of the measurement.
 * @param value The value of the measurement.
 */
- (void)setMeasurementWithName:(NSString *)name value:(NSNumber *)value;

/**
 * Set a measurement with specific unit.
 * @note Setting a measurement with the same name on the same transaction multiple times only
 * keeps the last value.
 * @param name The name of the measurement.
 * @param value The value of the measurement.
 * @param unit The unit the value is measured in.
 */
- (void)setMeasurementWithName:(NSString *)name
                         value:(NSNumber *)value
                          unit:(SentryObjCMeasurementUnit *)unit;

/// Finishes the span by setting the end time.
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 * @param status The status of this span.
 */
- (void)finishWithStatus:(SentryObjCSpanStatus)status;

/**
 * Returns the trace information that could be sent as a sentry-trace header.
 * @return The trace header.
 */
- (SentryObjCTraceHeader *)toTraceHeader;

/**
 * Returns the baggage HTTP header.
 * @return The baggage header string, or @c nil if unavailable.
 */
- (nullable NSString *)baggageHttpHeader;

@end

NS_ASSUME_NONNULL_END
