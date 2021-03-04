#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanContext.h"
#import "SentrySpanProtocol.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

NS_SWIFT_NAME(Span)
@interface SentrySpan : NSObject <SentrySpan, SentrySerializable>
SENTRY_NO_INIT

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
 * Init a SentrySpan with given tracer, name and context.
 *
 * @param tracer The tracer responsable for this span.
 * @param name The name of the span.
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithTracer:(SentryTracer *)tracer
                          name:(NSString *)name
                       context:(SentrySpanContext *)context;

/**
 * Init a SentrySpan with given name and context.
 *
 * @param name The name of the span.
 * @param context This span context information.
 *
 * @return SentrySpan
 */
- (instancetype)initWithName:(NSString *)name
                     context:(SentrySpanContext *)context;

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
