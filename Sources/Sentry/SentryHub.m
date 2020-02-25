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
#import <Sentry/SentryStackLayer.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryIntegrationProtocol.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryLog.h>
#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryStackLayer.h"
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

@implementation SentryHub

- (instancetype)init {
    if (self = [super init]) {
        self.scope = [[SentryScope alloc] init];
    }
    return self;
}

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        if (nil == scope) {
            [client captureEvent:event withScopes:@[self.scope]];
        } else {
            [client captureEvent:event withScopes:@[self.scope, scope]];
        }
    }
}

- (void)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        if (nil == scope) {
            [client captureMessage:message withScopes:@[self.scope]];
        } else {
            [client captureMessage:message withScopes:@[self.scope, scope]];
        }
    }
}

- (void)captureError:(NSError *)error withScope:(SentryScope *)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        if (nil == scope) {
            [client captureError:error withScopes:@[self.scope]];
        } else {
            [client captureError:error withScopes:@[self.scope, scope]];
        }
    }
}

-(void)captureException:(NSException *)exception withScope:(SentryScope *)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        if (nil == scope) {
            [client captureException:exception withScopes:@[self.scope]];
        } else {
            [client captureException:exception withScopes:@[self.scope, scope]];
        }
    }
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [self.scope addBreadcrumb:crumb];
}

- (SentryClient *_Nullable)getClient {
    return self.getClient;
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
