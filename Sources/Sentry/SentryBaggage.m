#import "SentryBaggage.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryUser.h"

@implementation SentryBaggage

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    userSegment:(nullable NSString *)userSegment
                     sampleRate:(nullable NSString *)sampleRate
{

    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _releaseName = releaseName;
        _environment = environment;
        _userSegment = userSegment;
        _sampleRate = sampleRate;
    }

    return self;
}

- (NSString *)toHTTPHeader
{
    NSMutableDictionary *information =
        @{ @"sentry-trace_id" : _traceId.sentryIdString, @"sentry-public_key" : _publicKey }
            .mutableCopy;

    if (_releaseName != nil)
        [information setValue:_releaseName forKey:@"sentry-release"];

    if (_environment != nil)
        [information setValue:_environment forKey:@"sentry-environment"];

    if (_userSegment != nil)
        [information setValue:_userSegment forKey:@"sentry-user_segment"];

    if (_sampleRate != nil)
        [information setValue:_sampleRate forKey:@"sentry-sample_rate"];

    return [SentrySerialization baggageEncodedDictionary:information];
}

@end
