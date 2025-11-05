#import "SentryTraceContext.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryTracer;
@class SentryScope;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTraceContext ()

/**
 * Initializes a SentryTraceContext with given properties.
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
 * Initializes a SentryTraceContext with given properties.
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

/**
 * Initializes a SentryTraceContext with data from a traceId, options and replayId.
 *
 *  @param traceId The current tracer.
 *  @param options The current active options.
 *  @param replayId The current session replay.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
                       replayId:(nullable NSString *)replayId;

@end

NS_ASSUME_NONNULL_END
