#import "SentryTraceState.h"
#import "SentryScope+Private.h"
#import "SentryTracer.h"
#import "SentryOptions+Private.h"
#import "SentryUser.h"
#import "SentryDsn.h"

@implementation SentryTraceStateUser

- (instancetype)initWithUserId:(NSString *)userId
                       segment:(NSString *)segment {
    if (self = [super init]) {
        _userId = userId;
        _segment = segment;
    }
    return self;
}

- (instancetype)initWithUser:(nullable SentryUser *)user
{
    return [self initWithUserId:user.userId segment: [user.data objectForKey:@"segment"]];
}

@end

@implementation SentryTraceState

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                           user:(nullable SentryTraceStateUser *)user {
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

- (nullable instancetype)initWithScope:(SentryScope *)scope
                               options:(SentryOptions *)options
{
    if (![scope.span isKindOfClass:[SentryTracer class]]) return nil;
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

@end
