#import <Foundation/Foundation.h>

@class SentryObjCId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Trace context containing information about a distributed trace.
 * This data is propagated between services via the @c baggage HTTP header.
 */
@interface SentryObjCTraceContext : NSObject

/**
 * UUID V4 encoded as a hexadecimal sequence with no dashes (e.g.
 * @c 771a43a4192642f0b136d5159a501700) that is a sequence of 32 hexadecimal digits.
 */
@property (nonatomic, readonly, strong) SentryObjCId *traceId;

/// Public key from the DSN used by the SDK.
@property (nonatomic, readonly, copy) NSString *publicKey;

/// The release name as specified in client options, usually: @c package\@x.y.z+build.
@property (nonatomic, readonly, copy, nullable) NSString *releaseName;

/// The environment name as specified in client options, for example @c staging.
@property (nonatomic, readonly, copy, nullable) NSString *environment;

/// The transaction name set on the scope.
@property (nonatomic, readonly, copy, nullable) NSString *transaction;

/// Serialized sample rate used for this trace.
@property (nonatomic, readonly, copy, nullable) NSString *sampleRate;

/// Serialized random value used to determine if the trace is sampled.
@property (nonatomic, readonly, copy, nullable) NSString *sampleRand;

/// Value indicating whether the trace was sampled.
@property (nonatomic, readonly, copy, nullable) NSString *sampled;

/// Id of the current session replay.
@property (nonatomic, readonly, copy, nullable) NSString *replayId;

/// The organization ID extracted from the DSN or configured explicitly.
@property (nonatomic, readonly, copy, nullable) NSString *orgId;

@end

NS_ASSUME_NONNULL_END
