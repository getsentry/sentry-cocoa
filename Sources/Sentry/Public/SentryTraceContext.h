#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#if !SDK_V9
#    import SENTRY_HEADER(SentrySerializable)
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryBaggage;
@class SentryId;
@class SentryOptions;
@class SentryScope;
@class SentryTracer;
@class SentryUser;

NS_SWIFT_NAME(TraceContext)
@interface SentryTraceContext : NSObject
#if !SDK_V9
                                <SentrySerializable>
#endif

/**
 * UUID V4 encoded as a hexadecimal sequence with no dashes (e.g. 771a43a4192642f0b136d5159a501700)
 * that is a sequence of 32 hexadecimal digits.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Public key from the DSN used by the SDK.
 */
@property (nonatomic, readonly) NSString *publicKey;

/**
 * The release name as specified in client options, usually: package@x.y.z+build.
 */
@property (nullable, nonatomic, readonly) NSString *releaseName;

/**
 * The environment name as specified in client options, for example staging.
 */
@property (nullable, nonatomic, readonly) NSString *environment;

/**
 * The transaction name set on the scope.
 */
@property (nullable, nonatomic, readonly) NSString *transaction;

/**
 * A subset of the scope's user context.
 */
#if !SDK_V9
@property (nullable, nonatomic, readonly) NSString *userSegment;
#endif

/**
 * Serialized sample rate used for this trace.
 */
@property (nullable, nonatomic, readonly) NSString *sampleRate;

/**
 * Serialized random value used to determine if the trace is sampled.
 */
@property (nullable, nonatomic, readonly) NSString *sampleRand;

/**
 * Value indicating whether the trace was sampled.
 */
@property (nullable, nonatomic, readonly) NSString *sampled;

/**
 * Id of the current session replay.
 */
@property (nullable, nonatomic, readonly) NSString *replayId;

/**
 * Initializes a SentryTraceContext with given properties.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

/**
 * Initializes a SentryTraceContext with given properties.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

/**
 * Initializes a SentryTraceContext with data from scope and options.
 */
- (nullable instancetype)initWithScope:(SentryScope *)scope options:(SentryOptions *)options;

/**
 * Initializes a SentryTraceContext with data from a dictionary.
 */
- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary;

/**
 * Initializes a SentryTraceContext with data from a trace, scope and options.
 */
- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SentryOptions *)options;

#if SDK_V9
/**
 * Initializes a SentryTraceContext with data from a traceId, options and replayId.
 *
 *  @param traceId The current tracer.
 *  @param options The current active options.
 *  @param replayId The current session replay.
 */
#else
/**
 * Initializes a SentryTraceContext with data from a traceId, options, userSegment and replayId.
 *
 *  @param traceId The current tracer.
 *  @param options The current active options.
 *  @param userSegment You can retrieve this usually from the `scope.userObject.segment`.
 *  @param replayId The current session replay.
 */
#endif
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                       replayId:(nullable NSString *)replayId;

/**
 * Create a SentryBaggage with the information of this SentryTraceContext.
 */
- (SentryBaggage *)toBaggage;
@end

NS_ASSUME_NONNULL_END
