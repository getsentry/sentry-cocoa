#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySampleDecision.h"
#import "SentrySpanContext.h"
#import "SentryTransactionNameSource.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context for a transaction (root span).
 *
 * Transactions represent high-level operations that span multiple lower-level spans.
 * Examples include page loads, navigation events, or API requests.
 *
 * @see SentrySDK
 * @see SentrySpanContext
 */
@interface SentryTransactionContext : SentrySpanContext

SENTRY_NO_INIT

/**
 * Human-readable name of the transaction.
 *
 * Examples: "/api/users", "MainActivity.onCreate", "button.click".
 */
@property (nonatomic, readonly) NSString *name;

/**
 * Source indicating how the transaction name was determined.
 *
 * Used for grouping and quality scoring in Sentry.
 */
@property (nonatomic, readonly) SentryTransactionNameSource nameSource;

/**
 * Sample rate applied to this transaction.
 *
 * A value between 0.0 and 1.0 indicating the probability this transaction is sampled.
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * Random value used to determine if this transaction is sampled.
 *
 * Compared against @c sampleRate to make the sampling decision.
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRand;

/**
 * Whether the parent transaction/span is sampled.
 *
 * Used in distributed tracing to propagate sampling decisions.
 */
@property (nonatomic) SentrySampleDecision parentSampled;

/**
 * Sample rate of the parent transaction.
 *
 * Propagated from the parent in distributed tracing.
 */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;

/**
 * Random sampling value from the parent transaction.
 *
 * Propagated from the parent in distributed tracing.
 */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;

/**
 * Whether this transaction context is for app launch profiling.
 *
 * @warning Internal use. Set by the SDK for sampling app launch profiles.
 */
@property (nonatomic, assign) BOOL forNextAppLaunch;

/**
 * Creates a transaction context with name and operation.
 *
 * @param name The transaction name.
 * @param operation The operation type.
 * @return A new transaction context instance.
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Creates a transaction context with sampling parameters.
 *
 * @param name The transaction name.
 * @param operation The operation type.
 * @param sampled Whether this transaction is sampled.
 * @param sampleRate The sample rate applied.
 * @param sampleRand Random value used for sampling.
 * @return A new transaction context instance.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;

/**
 * Creates a transaction context with full trace and sampling information.
 *
 * Used for distributed tracing to continue a trace from another service.
 *
 * @param name The transaction name.
 * @param operation The operation type.
 * @param traceId The trace ID.
 * @param spanId The span ID for this transaction.
 * @param parentSpanId The parent span ID, or @c nil if this is the root.
 * @param parentSampled Whether the parent is sampled.
 * @param parentSampleRate Sample rate of the parent.
 * @param parentSampleRand Random sampling value from the parent.
 * @return A new transaction context instance.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@end

NS_ASSUME_NONNULL_END
