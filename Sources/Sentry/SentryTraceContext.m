#import "SentryTraceContext.h"
#import "SentryBaggage.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentryTracer.h"
#import "SentryUser.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTraceContextUser

- (instancetype)initWithUserId:(nullable NSString *)userId segment:(nullable NSString *)segment
{
    if (self = [super init]) {
        _userId = userId;
        _segment = segment;
    }
    return self;
}

- (instancetype)initWithUser:(nullable SentryUser *)user
{
    NSString *segment;
    if ([user.data[@"segment"] isKindOfClass:[NSString class]]) {
        segment = user.data[@"segment"];
    }

    return [self initWithUserId:user.userId segment:segment];
}

@end

@implementation SentryTraceContext

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                           user:(nullable SentryTraceContextUser *)user
                     sampleRate:(nullable NSNumber *)sampleRate
{
    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _environment = environment;
        _releaseName = releaseName;
        _transaction = transaction;
        _user = user;
        _sampleRate = sampleRate;
    }
    return self;
}

- (nullable instancetype)initWithScope:(SentryScope *)scope
                               options:(SentryOptions *)options {
    SentryTracer *tracer = [SentryTracer getTracer:scope.span];
    if (tracer == nil) {
        return nil;
    } else {
        return [self initWithTracer:tracer scope:scope options:options];
    }
}

- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SentryOptions *)options
{
    if (tracer.context.traceId == nil || options.parsedDsn == nil)
        return nil;

    SentryTraceContextUser *stateUser;
    if (scope.userObject != nil && options.sendDefaultPii)
        stateUser = [[SentryTraceContextUser alloc] initWithUser:scope.userObject];
    
    NSNumber *sampleRate = nil;
    if ([tracer.context isKindOfClass:[SentryTransactionContext class]]) {
        sampleRate = [(SentryTransactionContext *)tracer.context sampleRate];
    }

    return [self initWithTraceId:tracer.context.traceId
                       publicKey:options.parsedDsn.url.user
                     releaseName:options.releaseName
                     environment:options.environment
                     transaction:tracer.name
                            user:stateUser
                      sampleRate:sampleRate];
}

- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary
{
    SentryId *traceId = [[SentryId alloc] initWithUUIDString:dictionary[@"trace_id"]];
    NSString *publicKey = dictionary[@"public_key"];
    if (traceId == nil || publicKey == nil)
        return nil;

    SentryTraceContextUser *user;
    if (dictionary[@"user"] != nil) {
        NSDictionary *userInfo = dictionary[@"user"];
        user = [[SentryTraceContextUser alloc] initWithUserId:userInfo[@"id"]
                                                      segment:userInfo[@"segment"]];
    } else {
        
    }
    
    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:dictionary[@"release"]
                     environment:dictionary[@"environment"]
                     transaction:dictionary[@"transaction"]
                            user:user
                      sampleRate:dictionary[@"sample_rate"]
    ];
}

- (SentryBaggage *)toBaggage
{
    SentryBaggage *result = [[SentryBaggage alloc] initWithTraceId:_traceId
                                                         publicKey:_publicKey
                                                       releaseName:_releaseName
                                                       environment:_environment
                                                       transaction:_transaction
                                                            userId:[_user userId]
                                                       userSegment:[_user segment]
                                                        sampleRate:@0];
    return result;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *result =
        @{ @"trace_id" : _traceId.sentryIdString, @"public_key" : _publicKey }.mutableCopy;

    if (_releaseName != nil)
        [result setValue:_releaseName forKey:@"release"];

    if (_environment != nil)
        [result setValue:_environment forKey:@"environment"];

    if (_transaction != nil)
        [result setValue:_transaction forKey:@"transaction"];

    if (_user != nil) {
        NSMutableDictionary *userDictionary = [[NSMutableDictionary alloc] init];
        if (_user.userId != nil)
            userDictionary[@"id"] = _user.userId;

        if (_user.segment != nil)
            userDictionary[@"segment"] = _user.segment;

        if (userDictionary.count > 0)
            [result setValue:userDictionary forKey:@"user"];
    }

    return result;
}

@end

NS_ASSUME_NONNULL_END
