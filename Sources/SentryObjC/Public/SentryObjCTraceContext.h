#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

@class SentryBaggage;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Trace context for distributed tracing.
 *
 * @see SentrySpan
 */
@interface SentryTraceContext : NSObject <SentrySerializable>

/** UUID V4 encoded as 32 hexadecimal digits. */
@property (nonatomic, readonly) SentryId *traceId;

/** Public key from the DSN. */
@property (nonatomic, readonly) NSString *publicKey;

/** Release name, e.g. package@x.y.z+build. */
@property (nullable, nonatomic, readonly) NSString *releaseName;

/** Environment name, e.g. staging. */
@property (nullable, nonatomic, readonly) NSString *environment;

/** Transaction name from the scope. */
@property (nullable, nonatomic, readonly) NSString *transaction;

/** Serialized sample rate. */
@property (nullable, nonatomic, readonly) NSString *sampleRate;

/** Serialized random value for sampling. */
@property (nullable, nonatomic, readonly) NSString *sampleRand;

/** Whether the trace was sampled. */
@property (nullable, nonatomic, readonly) NSString *sampled;

/** Id of the current session replay. */
@property (nullable, nonatomic, readonly) NSString *replayId;

/** Creates a SentryBaggage from this trace context. */
- (SentryBaggage *)toBaggage;

@end

NS_ASSUME_NONNULL_END
