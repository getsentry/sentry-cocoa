//
//  SentryHub.m
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryStackLayer.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySDK.h"
#import "SentryLog.h"

@interface SentryHub()

@property (nonatomic, strong) NSMutableArray<SentryStackLayer *> *stack;

@end

@implementation SentryHub

- (instancetype)init {
    if (self = [super init]) {
        SentryScope *scope = [[SentryScope alloc] init];
        SentryStackLayer *layer = [[SentryStackLayer alloc] init];
        layer.scope = scope;
        [self setStack:[@[layer] mutableCopy]];
    }
    return self;
}

- (void)captureEvent:(SentryEvent *)event {
    SentryClient *client = [self getClient];
    if (nil != client) {
        [client captureEvent:event withScope:[self getScope]];
    }
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [[self getScope] addBreadcrumb:crumb withMaxBreadcrumbs:[self getClient].options.maxBreadcrumbs];
}

- (SentryClient * _Nullable)getClient {
    if (nil != [self getStackTop]) {
        return [[self getStackTop] client];
    }
    return nil;
}

- (void)bindClient:(SentryClient * _Nullable)client {
    if (nil != [self getStackTop]) {
        [self getStackTop].client = client;

        [self doInstallIntegrations];
    }
}

- (SentryStackLayer *)getStackTop {
    return self.stack[self.stack.count - 1];
}

- (SentryScope *)getScope {
    return [self getStackTop].scope;
}

- (SentryScope *)pushScope {
    SentryScope * scope = [[[self getStackTop] scope] copy];
    SentryClient * client = [[self getClient] copy];
    SentryStackLayer *newLayer = [[SentryStackLayer alloc] init];
    newLayer.scope = scope;
    newLayer.client = client;
    [self.stack addObject:newLayer];
    return scope;
}

- (void)popScope {
    [self.stack removeLastObject];
}

- (void)withScope:(void(^)(SentryScope * scope))callback {
    SentryScope *scope = [self pushScope];
    callback(scope);
    [self popScope];
}

- (void)configureScope:(void(^)(SentryScope *scope))callback {
    SentryStackLayer *top = [self getStackTop];
    if (nil != top.client && nil != top.scope) {
        callback(top.scope);
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

/**
 * Checks if integration is activated for bound client.
 */
- (BOOL)isIntegrationActiveInBoundClient:(NSString *)integrationName {
    return NSNotFound != [[self getClient].options.integrations indexOfObject:integrationName];
}

@end
