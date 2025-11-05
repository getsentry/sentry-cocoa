#import "SentryTraceContext.h"
#import "SentryBaggage.h"
#import "SentryDefines.h"
#import "SentryDsn.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryOptionsInternal+Private.h"
#import "SentrySampleDecision.h"
#import "SentryScope+Private.h"
#import "SentryScope+PrivateSwift.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTraceContext

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
                        replayId:replayId];
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
    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _environment = environment;
        _releaseName = releaseName;
        _transaction = transaction;
        _sampleRand = sampleRand;
        _sampleRate = sampleRate;
        _sampled = sampled;
        _replayId = replayId;
    }
    return self;
}

- (nullable instancetype)initWithScope:(SentryScope *)scope options:(SentryOptions *)options
{
    SentryTracer *tracer = [SentryTracer getTracer:scope.span];
    if (tracer == nil) {
        return nil;
    }
    return [self initWithTracer:tracer scope:scope options:options];
}

- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SentryOptions *)options
{
    if (tracer.traceId == nil || options.parsedDsn == nil) {
        return nil;
    }

    NSString *serializedSampleRand = nil;
    NSNumber *sampleRand = [tracer.transactionContext sampleRand];
    if (sampleRand != nil) {
        serializedSampleRand = [NSString stringWithFormat:@"%f", sampleRand.doubleValue];
    }

    NSString *serializedSampleRate = nil;
    NSNumber *sampleRate = [tracer.transactionContext sampleRate];
    if (sampleRate != nil) {
        serializedSampleRate = [NSString stringWithFormat:@"%f", sampleRate.doubleValue];
    }
    NSString *sampled = nil;
    if (tracer.sampled != kSentrySampleDecisionUndecided) {
        sampled
            = tracer.sampled == kSentrySampleDecisionYes ? kSentryTrueString : kSentryFalseString;
    }

    return [self initWithTraceId:tracer.traceId
                       publicKey:SENTRY_UNWRAP_NULLABLE(NSString, options.parsedDsn.url.user)
                     releaseName:options.releaseName
                     environment:options.environment
                     transaction:tracer.transactionContext.name
                      sampleRate:serializedSampleRate
                      sampleRand:serializedSampleRand
                         sampled:sampled
                        replayId:scope.replayId];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
                       replayId:(nullable NSString *)replayId;
{
    return [[SentryTraceContext alloc]
        initWithTraceId:traceId
              publicKey:SENTRY_UNWRAP_NULLABLE(NSString, options.parsedDsn.url.user)
            releaseName:options.releaseName
            environment:options.environment
            transaction:nil
             sampleRate:nil
             sampleRand:nil
                sampled:nil
               replayId:replayId];
}

- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary
{
    NSString *_Nullable rawTraceId = dictionary[@"trace_id"];
    if (rawTraceId == nil || ![rawTraceId isKindOfClass:[NSString class]]) {
        SENTRY_LOG_ERROR(@"Invalid trace_id: %@", rawTraceId);
        return nil;
    }

    SentryId *traceId =
        [[SentryId alloc] initWithUUIDString:SENTRY_UNWRAP_NULLABLE(NSString, rawTraceId)];
    NSString *publicKey = dictionary[@"public_key"];
    if (traceId == nil || publicKey == nil)
        return nil;

    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:dictionary[@"release"]
                     environment:dictionary[@"environment"]
                     transaction:dictionary[@"transaction"]
                      sampleRate:dictionary[@"sample_rate"]
                      sampleRand:dictionary[@"sample_rand"]
                         sampled:dictionary[@"sampled"]
                        replayId:dictionary[@"replay_id"]];
}

- (SentryBaggage *)toBaggage
{
    SentryBaggage *result = [[SentryBaggage alloc] initWithTraceId:_traceId
                                                         publicKey:_publicKey
                                                       releaseName:_releaseName
                                                       environment:_environment
                                                       transaction:_transaction
                                                        sampleRate:_sampleRate
                                                        sampleRand:_sampleRand
                                                           sampled:_sampled
                                                          replayId:_replayId];
    return result;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *result =
        @{ @"trace_id" : _traceId.sentryIdString, @"public_key" : _publicKey }.mutableCopy;

    if (_releaseName != nil) {
        [result setValue:_releaseName forKey:@"release"];
    }

    if (_environment != nil) {
        [result setValue:_environment forKey:@"environment"];
    }

    if (_transaction != nil) {
        [result setValue:_transaction forKey:@"transaction"];
    }

    if (_sampleRand != nil) {
        [result setValue:_sampleRand forKey:@"sample_rand"];
    }

    if (_sampleRate != nil) {
        [result setValue:_sampleRate forKey:@"sample_rate"];
    }

    if (_sampled != nil) {
        [result setValue:_sampleRate forKey:@"sampled"];
    }

    if (_replayId != nil) {
        [result setValue:_replayId forKey:@"replay_id"];
    }

    return result;
}

@end

NS_ASSUME_NONNULL_END
