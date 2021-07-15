#import <Foundation/Foundation.h>
#import <NSData+Sentry.h>
#import <SentryBreadcrumb.h>
#import <SentryCrashJSONCodec.h>
#import <SentryCrashJSONCodecObjC.h>
#import <SentryCrashScopeObserver.h>
#import <SentryLog.h>
#import <SentryScopeSyncC.h>
#import <SentryUser.h>

@interface
SentryCrashScopeObserver ()
@property (nonatomic, assign) NSInteger maxBreadcrumbs;

@end

@implementation SentryCrashScopeObserver

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        self.maxBreadcrumbs = maxBreadcrumbs;
        sentryscopesync_configureBreadcrumbs(maxBreadcrumbs);
    }

    return self;
}

- (void)setUser:(nullable SentryUser *)user
{
    [self syncScope:user
        serialize:^{ return [user serialize]; }
        scopeSync:^(const void *bytes) { sentryscopesync_setUser(bytes); }];
}

- (void)setDist:(nullable NSString *)dist
{
    [self syncScope:dist
        serialize:^{ return dist; }
        scopeSync:^(const void *bytes) { sentryscopesync_setDist(bytes); }];
}

- (void)setEnvironment:(nullable NSString *)environment
{
    [self syncScope:environment
        serialize:^{ return environment; }
        scopeSync:^(const void *bytes) { sentryscopesync_setEnvironment(bytes); }];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    [self syncScope:context scopeSync:^(const void *bytes) { sentryscopesync_setContext(bytes); }];
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    [self syncScope:extras scopeSync:^(const void *bytes) { sentryscopesync_setExtras(bytes); }];
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    [self syncScope:tags scopeSync:^(const void *bytes) { sentryscopesync_setTags(bytes); }];
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    [self syncScope:fingerprint
        serialize:^{
            NSArray *result = nil;
            if (fingerprint.count > 0) {
                result = fingerprint;
            }
            return result;
        }
        scopeSync:^(const void *bytes) { sentryscopesync_setFingerprint(bytes); }];
}

- (void)setLevel:(enum SentryLevel)level
{
    if (level == kSentryLevelNone) {
        sentryscopesync_setLevel(NULL);
        return;
    }

    NSString *levelAsString = SentryLevelNames[level];
    NSData *json = [self toJSONAsCString:levelAsString];

    sentryscopesync_setLevel([json bytes]);
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    NSDictionary *serialized = [crumb serialize];
    NSData *json = [self toJSONAsCString:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_addBreadcrumb([json bytes]);
}

- (void)clearBreadcrumbs
{
    sentryscopesync_clearBreadcrumbs();
}

- (void)clear
{
    sentryscopesync_clear();
}

- (void)syncScope:(NSDictionary *)dict scopeSync:(void (^)(const void *))scopeSync
{
    [self syncScope:dict
          serialize:^{
              NSDictionary *result = nil;
              if (dict.count > 0) {
                  result = dict;
              }
              return result;
          }
          scopeSync:scopeSync];
}

- (void)syncScope:(id)object
        serialize:(nullable id (^)(void))serialize
        scopeSync:(void (^)(const void *))scopeSync
{
    if (object == nil) {
        scopeSync(NULL);
        return;
    }

    id serialized = serialize();
    if (serialized == nil) {
        scopeSync(NULL);
        return;
    }

    NSData *jsonCString = [self toJSONAsCString:serialized];
    if (jsonCString == nil) {
        return;
    }

    scopeSync([jsonCString bytes]);
}

- (nullable NSData *)toJSONAsCString:(id)toSerialize
{
    NSError *error = nil;
    NSData *json = nil;
    if (toSerialize != nil) {
        json = [SentryCrashJSONCodec encode:toSerialize
                                    options:SentryCrashJSONEncodeOptionSorted
                                      error:&error];
        if (error != nil) {
            NSString *message = [NSString stringWithFormat:@"Could not serialize %@", error];
            [SentryLog logWithMessage:message andLevel:kSentryLevelError];
            return nil;
        }
    }

    // C strings need to be null terminated
    return [json nullTerminated];
}

@end
