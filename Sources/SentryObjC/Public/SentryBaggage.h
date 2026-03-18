#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_BAGGAGE_HEADER = @"baggage";

/**
 * Baggage for distributed tracing propagation.
 *
 * Carries trace context metadata across service boundaries via HTTP headers.
 * Used for correlating traces across distributed systems.
 *
 * @see SentryTraceContext
 */
@interface SentryBaggage : NSObject

/// The trace ID for this distributed trace.
@property (nonatomic, readonly) SentryId *traceId;

/// The Sentry project public key (DSN public key).
@property (nonatomic, readonly) NSString *publicKey;

/// The release name/version of the application.
@property (nullable, nonatomic, readonly) NSString *releaseName;

/// The environment name (e.g., "production", "staging").
@property (nullable, nonatomic, readonly) NSString *environment;

/// The transaction name being traced.
@property (nullable, nonatomic, readonly) NSString *transaction;

/// The user ID associated with this trace.
@property (nullable, nonatomic, readonly) NSString *userId;

/// Random value used for deterministic sampling decisions.
@property (nullable, nonatomic, readonly) NSString *sampleRand;

/// The sample rate applied to this trace (as a string).
@property (nullable, nonatomic, readonly) NSString *sampleRate;

/// Whether this trace was sampled (@c "true" or @c "false").
@property (nullable, nonatomic, strong) NSString *sampled;

/// Session replay ID if replay is active for this trace.
@property (nullable, nonatomic, strong) NSString *replayId;

/**
 * Creates baggage with trace context.
 *
 * @param traceId The trace ID.
 * @param publicKey The DSN public key.
 * @param releaseName The release name.
 * @param environment The environment.
 * @param transaction The transaction name.
 * @param sampleRate The sample rate.
 * @param sampled Whether the trace was sampled.
 * @param replayId The replay ID.
 * @return A new baggage instance.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

/**
 * Creates baggage with trace context and sample randomness.
 *
 * @param traceId The trace ID.
 * @param publicKey The DSN public key.
 * @param releaseName The release name.
 * @param environment The environment.
 * @param transaction The transaction name.
 * @param sampleRate The sample rate.
 * @param sampleRand Random value for sampling decisions.
 * @param sampled Whether the trace was sampled.
 * @param replayId The replay ID.
 * @return A new baggage instance.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

/**
 * Serializes baggage to an HTTP header value.
 *
 * Merges Sentry baggage with any original baggage from upstream services.
 *
 * @param originalBaggage Original baggage key-value pairs from upstream.
 * @return HTTP header value suitable for the @c baggage header.
 */
- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *)originalBaggage;

@end

NS_ASSUME_NONNULL_END
