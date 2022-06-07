#import "SentryBaggage.h"
#import "SentryTraceState.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentryTracer.h"
#import "SentryUser.h"

@implementation SentryBaggage

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                         userId:(nullable NSString *)userId
                    userSegment:(nullable NSString *)userSegment
{
    
    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _releaseName = releaseName;
        _environment = environment;
        _transaction = transaction;
        _userId = userId;
        _userSegment = userSegment;
    }
    
    return  self;
}


- (nullable NSString *)toHTTPHeader
{
    NSMutableDictionary *information =
        @{ @"sentry-traceid" : _traceId.sentryIdString,
           @"sentry-publickey" : _publicKey
        }.mutableCopy;

    if (_releaseName != nil)
        [information setValue:_releaseName forKey:@"sentry-release"];

    if (_environment != nil)
        [information setValue:_environment forKey:@"sentry-environment"];

    if (_transaction != nil)
        [information setValue:_transaction forKey:@"sentry-transaction"];
    
    if (_userId != nil)
        [information setValue:_userId forKey:@"sentry-userid"];

    if (_userSegment != nil)
        [information setValue:_userSegment forKey:@"sentry-usersegment"];
    
    return [SentrySerialization urlEncodedDictionary:information];
}

@end
