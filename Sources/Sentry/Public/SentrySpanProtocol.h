#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId, SentryId, SentryHub;

NS_SWIFT_NAME(Span)
@protocol SentrySpan <SentrySerializable>

/**
 *Span name.
 */
@property (nonatomic, copy) NSString *name;

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
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Starts a child span.
 *
 * @param name Child span name.
 * @param operation Short code identifying the type of operation the span is measuring.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithName:(NSString *)name
                           operation:(NSString *)operation
    NS_SWIFT_NAME(startChild(name:operation:));

/**
 * Starts a child span.
 *
 * @param name Child span name.
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithName:(NSString *)name
                           operation:(NSString *)operation
                         description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(name:operation:description:));

/**
 * Sets an extra.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

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

@end

NS_ASSUME_NONNULL_END
