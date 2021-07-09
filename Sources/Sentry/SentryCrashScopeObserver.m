#import <Foundation/Foundation.h>
#import <NSData+Sentry.h>
#import <SentryCrashJSONCodec.h>
#import <SentryCrashJSONCodecObjC.h>
#import <SentryCrashScopeObserver.h>
#import <SentryLog.h>
#import <SentryScopeSyncC.h>
#import <SentryUser.h>

@implementation SentryCrashScopeObserver

- (void)setUser:(nullable SentryUser *)user
{
    [self syncScope:user
        serialize:^{ return @ { @"user" : [user serialize] }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setUserJSON(bytes); }];
}

- (void)setDist:(nullable NSString *)dist
{
    [self syncScope:dist
        serialize:^{ return @ { @"dist" : dist }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setDist(bytes); }];
}

- (void)addBreadcrumb:(nonnull SentryBreadcrumb *)crumb
{
}

- (void)clear
{
    sentryscopesync_clear();
}

- (void)clearBreadcrumbs
{
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    [self syncScope:context
        serialize:^{ return @ { @"context" : context }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setContext(bytes); }];
}

- (void)setEnvironment:(nullable NSString *)environment
{
    [self syncScope:environment
        serialize:^{ return @ { @"environment" : environment }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setEnvironment(bytes); }];
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    [self syncScope:extras
        serialize:^{ return @ { @"extra" : extras }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setExtras(bytes); }];
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    [self syncScope:fingerprint
        serialize:^{ return @ { @"fingerprint" : fingerprint }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setFingerprint(bytes); }];
}

- (void)setLevel:(enum SentryLevel)level
{
    NSDictionary *serialized = @{ @"level" : SentryLevelNames[level] };
    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_setLevel([json bytes]);
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    [self syncScope:tags
        serialize:^{ return @ { @"tags" : tags }; }
        scopeSync:^(const void *bytes) { sentryscopesync_setTags(bytes); }];
}

- (void)syncScope:(nullable id)object
        serialize:(NSDictionary * (^)(void))serialize
        scopeSync:(void (^)(const void *))scopeSync
{
    if (object == nil) {
        scopeSync(NULL);
        return;
    }

    NSDictionary *serialized = serialize();
    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    scopeSync([json bytes]);
}

- (nullable NSData *)getBytes:(NSDictionary *)serialized
{
    NSError *error = nil;
    NSData *json = nil;
    if (serialized != nil) {
        json = [SentryCrashJSONCodec encode:serialized
                                    options:SentryCrashJSONEncodeOptionSorted
                                      error:&error];
        if (error != nil) {
            NSString *message = [NSString stringWithFormat:@"Could not serialize %@", error];
            [SentryLog logWithMessage:message andLevel:kSentryLevelError];
            return nil;
        }
    }

    // Remove first { and last }
    NSRange range = NSMakeRange(1, [json length] - 2);
    json = [json subdataWithRange:range];
    json = [json nullTerminated];
    return json;
}

@end
