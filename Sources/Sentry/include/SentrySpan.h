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
@end

NS_ASSUME_NONNULL_END
