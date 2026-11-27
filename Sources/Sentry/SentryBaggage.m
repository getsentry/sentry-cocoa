#import "SentryBaggage.h"
#import "SentryLogC.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryUser.h"

@implementation SentryBaggage

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
{
    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:releaseName
                     environment:environment
                     transaction:transaction
                      sampleRate:sampleRate
                      sampleRand:nil
                         sampled:sampled
                        replayId:replayId
                           orgId:nil];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
{
    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:releaseName
                     environment:environment
                     transaction:transaction
                      sampleRate:sampleRate
                      sampleRand:sampleRand
                         sampled:sampled
                        replayId:replayId
                           orgId:nil];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
                          orgId:(nullable NSString *)orgId
{

    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _releaseName = releaseName;
        _environment = environment;
        _transaction = transaction;
        _sampleRate = sampleRate;
        _sampleRand = sampleRand;
        _sampled = sampled;
        _replayId = replayId;
        _orgId = orgId;
    }

    return self;
}

- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *_Nullable)originalBaggage
{
    NSMutableDictionary<NSString *, NSString *> *information
        = originalBaggage.mutableCopy ?: [[NSMutableDictionary alloc] init];

    [information setValue:_traceId.sentryIdString forKey:@"sentry-trace_id"];
    [information setValue:_publicKey forKey:@"sentry-public_key"];

    if (_releaseName != nil) {
        [information setValue:_releaseName forKey:@"sentry-release"];
    }

    if (_environment != nil) {
        [information setValue:_environment forKey:@"sentry-environment"];
    }

    if (_transaction != nil) {
        [information setValue:_transaction forKey:@"sentry-transaction"];
    }

    if (_sampleRand != nil) {
        [information setValue:_sampleRand forKey:@"sentry-sample_rand"];
    }

    if (_sampleRate != nil) {
        [information setValue:_sampleRate forKey:@"sentry-sample_rate"];
    }

    if (_sampled != nil) {
        [information setValue:_sampled forKey:@"sentry-sampled"];
    }

    if (_replayId != nil) {
        [information setValue:_replayId forKey:@"sentry-replay_id"];
    }

    if (_orgId != nil) {
        [information setValue:_orgId forKey:@"sentry-org_id"];
    }

    return [SentryBaggageSerialization encodeDictionary:information];
}

@end
