#import "SentryTraceState.h"
#import "SentryDsn.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentryTracer.h"
#import "SentryUser.h"

@implementation SentryTraceStateUser

- (instancetype)initWithUserId:(NSString *)userId segment:(NSString *)segment
{
    if (self = [super init]) {
        _userId = userId;
        _segment = segment;
    }
    return self;
}

- (instancetype)initWithUser:(nullable SentryUser *)user
{
    return [self initWithUserId:user.userId segment:[user.data objectForKey:@"segment"]];
}

@end

@implementation SentryTraceState

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                           user:(nullable SentryTraceStateUser *)user
{
    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _environment = environment;
        _releaseName = releaseName;
        _transaction = transaction;
        _user = user;
    }
    return self;
}

- (nullable instancetype)initWithScope:(SentryScope *)scope options:(SentryOptions *)options
{
    if (![scope.span isKindOfClass:[SentryTracer class]])
        return nil;
    return [self initWithTracer:scope.span scope:scope options:options];
}

- (instancetype)initWithTracer:(SentryTracer *)tracer
                         scope:(nullable SentryScope *)scope
                       options:(SentryOptions *)options
{

    return [self initWithTraceId:tracer.context.traceId
                       publicKey:options.parsedDsn.url.user
                     releaseName:options.releaseName
                     environment:options.environment
                     transaction:tracer.name
                            user:[[SentryTraceStateUser alloc] initWithUser:scope.userObject]];
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *result = @{
            @"trace_id": _traceId.sentryIdString,
            @"public_key": _publicKey
        }.mutableCopy;
    
    if (_releaseName != nil) [result setValue:_releaseName forKey:@"release"];
    
    if (_environment != nil) [result setValue:_environment forKey:@"environment"];
    
    if (_transaction != nil) [result setValue:_transaction forKey:@"transaction"];
    
    if (_user != nil) [result setValue:@{ @"id": _user.userId, @"segment": _user.segment } forKey:@"user"];
    
    return result;
}

@end
