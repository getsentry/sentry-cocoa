#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_BAGGAGE_HEADER = @"baggage";

/**
 * Baggage for distributed tracing propagation.
 *
 * @see SentryTraceContext
 */
@interface SentryBaggage : NSObject

@property (nonatomic, readonly) SentryId *traceId;
@property (nonatomic, readonly) NSString *publicKey;
@property (nullable, nonatomic, readonly) NSString *releaseName;
@property (nullable, nonatomic, readonly) NSString *environment;
@property (nullable, nonatomic, readonly) NSString *transaction;
@property (nullable, nonatomic, readonly) NSString *userId;
@property (nullable, nonatomic, readonly) NSString *sampleRand;
@property (nullable, nonatomic, readonly) NSString *sampleRate;
@property (nullable, nonatomic, strong) NSString *sampled;
@property (nullable, nonatomic, strong) NSString *replayId;

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *)originalBaggage;

@end

NS_ASSUME_NONNULL_END
