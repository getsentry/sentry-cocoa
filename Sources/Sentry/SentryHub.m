//
//  SentryHub.m
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryHub.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryIntegrationProtocol.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentryFileManager.h>
#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#import "SentryCrash.h"
#import "SentryFileManager.h"
#endif

@interface SentryHub()

@property (nonatomic, strong) SentryClient *_Nullable client;
@property (nonatomic, strong) SentryScope *_Nullable scope;
@property (nonatomic, strong) NSMutableArray<NSObject<SentryIntegrationProtocol> *> *installedIntegrations;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
}

@synthesize scope;

- (instancetype)initWithClient:(SentryClient *_Nullable)client andScope:(SentryScope *_Nullable)scope {
    if (self = [super init]) {
        self.scope = scope;
        [self bindClient:client];
        _sessionLock = [[NSObject alloc] init];
    }
    return self;
}

- (void)startSession {
    // TODO: This shouldn't be done here but since it can't be done during init (no client) and can't be done after bindClient (integrations runs)
    [self closeCachedSession];

    SentrySession *lastSession = nil;
    SentryScope *scope = [self getScope];
    @synchronized (_sessionLock) {
        if (nil != _session) {
            lastSession = _session;
        }
        _session = [[SentrySession alloc] init];
        [scope applyToSession:_session];
        [self storeCurrentSession:_session];
        // TODO: Capture outside the lock. Not the reference in the scope.
        [self captureSession:_session];
    }
    [lastSession endSession];
    [self captureSession:lastSession];
}

- (void)endSession {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }
    
    if (nil == currentSession) {
        // TODO: log
        return;
    }

    [currentSession endSession];
    [self captureSession:currentSession];
}

- (void)endSessionWithTimestamp:(NSDate*)timestamp {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }
    
    if (nil == currentSession) {
        // TODO: log
        return;
    }

    [currentSession endSessionWithTimestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session {
    [[[self getClient] fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession {
    [[[self getClient] fileManager] deleteCurrentSession];
}

BOOL _closedCachedSesson = NO;

// TODO: Ideally this would be done during init (read cached session to end it)
// Doing it here since at Init time the Hub still has no client. Requires external code to bind one.
// This method should not be public API
- (void)closeCachedSession {
    if (_closedCachedSesson) {
        return;
    }
    _closedCachedSesson = YES;
    
    SentrySession *session = [[[self getClient] fileManager] readCurrentSession];
    if (nil != session) {
        SentryClient *client = [self getClient];
        if (nil != session && nil != client) { // Make sure there's a client bound.
            NSDate *timestamp = [NSDate date];
            if (SentryCrash.sharedInstance.crashedLastLaunch) {
                [session crashedSession];
            }
            [session endSessionWithTimestamp:timestamp];
            [self deleteCurrentSession];
            [client captureSession:session];
        }
    }
}

- (void)captureSession:(SentrySession *)session {
    if (nil != session) {
        SentryClient *client = [self getClient];
        [client captureSession:session];
    }
}

- (void)incrementSessionErrors {
    @synchronized (_sessionLock) {
        [_session incrementErrors];
        [self storeCurrentSession:_session];
    }
}

- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureEvent:event withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureMessage:message withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureError:error withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureException:exception withScope:scope];
    }
    return nil;
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    SentryBeforeBreadcrumbCallback callback = [[[self client] options] beforeBreadcrumb];
    if (nil != callback) {
        crumb = callback(crumb);
    }
    if (nil == crumb) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Discarded Breadcrumb in `beforeBreadcrumb`"] andLevel:kSentryLogLevelDebug];
        return;
    }
    [self.scope addBreadcrumb:crumb];
}

- (SentryClient *_Nullable)getClient {
    return self.client;
}

- (SentryScope *)getScope {
    if (self.scope == nil) {
        self.scope = [[SentryScope alloc] init];
    }
    return self.scope;
}

- (void)bindClient:(SentryClient * _Nullable)client {
    self.client = client;
    [self doInstallIntegrations];
}

- (void)configureScope:(void(^)(SentryScope *scope))callback {
    if (nil != self.client && nil != self.scope) {
        callback(self.scope);
    }
}

/**
 * Install integrations and keeps ref in `SentryHub.integrations`
 */
- (void)doInstallIntegrations {
    if (nil == [self getClient]) {
        // Gatekeeper
        return;
    }
    SentryOptions *options = [self getClient].options;
    for (NSString *integrationName in [self getClient].options.integrations) {
        Class integrationClass = NSClassFromString(integrationName);
        if (nil == integrationClass) {
            NSString *logMessage = [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] couldn't find \"%@\" -> skipping.", integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        } else if ([SentrySDK.currentHub isIntegrationInstalled:integrationClass]) {
            NSString *logMessage = [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] already installed \"%@\" -> skipping.", integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        }
        id<SentryIntegrationProtocol> integrationInstance = [[integrationClass alloc] init];
        [integrationInstance installWithOptions:options];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Integration installed: %@", integrationName] andLevel:kSentryLogLevelDebug];
        [SentrySDK.currentHub.installedIntegrations addObject:integrationInstance];
    }
}

/**
 * Checks if a specific Integration (`integrationClass`) has been installed.
 * @return BOOL If instance of `integrationClass` exists within `SentryHub.installedIntegrations`.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass {
    for (id<SentryIntegrationProtocol> item in SentrySDK.currentHub.installedIntegrations) {
        if ([item isKindOfClass:integrationClass]) {
            return YES;
        }
    }
    return NO;
}

- (id _Nullable)getIntegration:(NSString *)integrationName {
    NSArray *integrations = [self getClient].options.integrations;
    if (![integrations containsObject:integrationName]) {
        return nil;
    }
    return [integrations objectAtIndex:[integrations indexOfObject:integrationName]];
}

@end
