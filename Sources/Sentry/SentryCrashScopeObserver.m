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
    NSDictionary *serialized = @{ @"user" : [user serialize] };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_setUserJSON([json bytes]);
}

- (void)setDist:(nullable NSString *)dist
{
    NSDictionary *serialized = @{ @"dist" : dist };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_setDist([json bytes]);
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
    NSDictionary *serialized = @{ @"context" : context };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_setContext([json bytes]);
}

- (void)setEnvironment:(nullable NSString *)environment
{
    NSDictionary *serialized = @{ @"environment" : environment };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }

    sentryscopesync_setEnvironment([json bytes]);
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
}

- (void)setLevel:(enum SentryLevel)level
{
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
}

- (nullable NSData *)getBytes:(NSDictionary *)serialized
{
    NSError *error = nil;
    NSData *json = nil;
    if (serialized != nil) {
        json = [SentryCrashJSONCodec encode:serialized
                                    options:SentryCrashJSONEncodeOptionSorted
                                      error:&error];
        json = [json nullTerminated];
        if (error != NULL) {
            NSString *message = [NSString stringWithFormat:@"Could not serialize %@", error];
            [SentryLog logWithMessage:message andLevel:kSentryLevelError];
            return nil;
        }
    }

    return json;
}

@end
