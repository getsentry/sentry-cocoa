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
    NSDictionary *serialized = @{ @"extra" : extras };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }
    sentryscopesync_setExtras([json bytes]);
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    NSDictionary *serialized = @{ @"fingerprint" : fingerprint };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }
    sentryscopesync_setFingerprint([json bytes]);
}

- (void)setLevel:(enum SentryLevel)level
{
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    NSDictionary *serialized = @{ @"tags" : tags };

    NSData *json = [self getBytes:serialized];
    if (json == nil) {
        return;
    }
    sentryscopesync_setTags([json bytes]);
}

- (nullable NSData *)getBytes:(NSDictionary *)serialized
{
    NSError *error = nil;
    NSData *json = nil;
    if (serialized != nil) {
        json = [SentryCrashJSONCodec encode:serialized
                                    options:SentryCrashJSONEncodeOptionSorted
                                      error:&error];
        if (error != NULL) {
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
