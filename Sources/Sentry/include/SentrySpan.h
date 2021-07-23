#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@interface SentrySpan : NSObject <SentrySpan, SentrySerializable>
SENTRY_NO_INIT

/**
 * The context information of the span.
 */
@property (nonatomic, readonly) SentrySpanContext *context;

/**
 * The timestamp of which the span ended.
 */
@property (nullable, nonatomic, strong) NSDate *timestamp;

/**
 * The start time of the span.
 */
@property (nullable, nonatomic, strong) NSDate *startTimestamp;

/**
 * An arbitrary mapping of additional metadata of the span.
 */
@property (nullable, readonly) NSDictionary<NSString *, id> *data;

/**
 * A key-value pairs holding additional data about the span.
 */
@property (nullable, readonly) NSDictionary<NSString *, id> *tags;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Init a SentrySpan with given tracer and context.
 *
 * @param tracer The tracer responsible for this span.
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithTracer:(SentryTracer *)tracer context:(SentrySpanContext *)context;

/**
 * Init a SentrySpan with given context.
 *
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithContext:(SentrySpanContext *)context;

/**
 * Starts a child span.
 *
 * @param operation Short code identifying the type of operation the span is measuring.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
    NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Sets an extra.
 */
- (void)setDataValue:(nullable id)value
              forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Sets a tag value.
 */
- (void)setTagValue:(nullable id)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Finishes the span by setting the end time.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 *
 * @param status The status of this span
 */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

/**
 * Returns a string that could be sent as a sentry-trace header.
 *
 * @return SentryTraceHeader.
 */
- (SentryTraceHeader *)toTraceHeader;

@end

NS_ASSUME_NONNULL_END
