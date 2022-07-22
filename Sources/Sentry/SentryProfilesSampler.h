#import "SentryRandom.h"
#import "SentrySampleDecision.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentrySamplingContext, SentryTracesSamplerDecision;

@interface SentryProfilesSamplerDecision : NSObject

@property (nonatomic, readonly) SentrySampleDecision decision;

@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRate;

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate;

@end

@interface SentryProfilesSampler : NSObject

/**
 *  A random number generator
 */
@property (nonatomic, strong) id<SentryRandom> random;

/**
 * Init a ProfilesSampler with given options and random generator.
 * @param options Sentry options with sampling configuration
 * @param random A random number generator
 * @param tracesSamplerDecision The sampler decision for whether to sample the trace that
 * the profile is coupled to.
 */
- (instancetype)initWithOptions:(SentryOptions *)options random:(id<SentryRandom>)random tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision;

/**
 * Init a ProfilesSampler with given options and a default Random generator.
 * @param options Sentry options with sampling configuration
 * @param tracesSamplerDecision The sampler decision for whether to sample the trace that
 * the profile is coupled to.
 */
- (instancetype)initWithOptions:(SentryOptions *)options tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision;

/**
 * Determines whether a profile should be sampled based on the context and options.
 */
- (SentryProfilesSamplerDecision *)sample:(SentrySamplingContext *)context;

@end

NS_ASSUME_NONNULL_END
