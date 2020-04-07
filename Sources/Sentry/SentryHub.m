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
#import "SentryFileManager.h"

#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySDK.h"
#import "SentryLog.h"
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

- (instancetype)init {
    if (self = [super init]) {
        self.scope = [self getScope];
        // TODO: needs a home. For now defining default release here to be set before integrations
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        if (nil != infoDict) {
            [self.scope setRelease:[NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"], infoDict[@"CFBundleShortVersionString"],
                infoDict[@"CFBundleVersion"]]];
        }
    }
    _sessionLock = [[NSObject alloc] init];
    return self;
}

- (void)startSession {
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
    [lastSession endSessionWithStatus:kSentrySessionStatusAbnormal timestamp:[NSDate date]];
    [self captureSession:lastSession];
}

- (void)endSession {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }

    [currentSession endSessionWithStatus:nil timestamp:[NSDate date]];
    [self captureSession:currentSession];
}

- (void)endSessionWithStatus:(SentrySessionStatus *)status
                   timestamp:(NSDate *)timestamp {
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

    [currentSession endSessionWithStatus:status timestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session {
    [[[self getClient] fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession {
    [[[self getClient] fileManager] deleteCurrentSession];
}

- (void)captureSession:(SentrySession *)session {
    if (nil != session) {
        SentryClient *client = [self getClient];
        [client captureSession:session];
    }
};

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
