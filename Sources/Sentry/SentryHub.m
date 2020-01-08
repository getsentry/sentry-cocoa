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

@property (nonatomic, strong) NSMutableArray<SentryStackLayer *> *stack;
@property (nonatomic, strong) NSMutableArray<NSObject<SentryIntegrationProtocol> *> *installedIntegrations;


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
* install integrations and populates `SentryHub.integrations`
* returns BOOL YES if count of installed integrations is equal to options.integrations
*/
- (BOOL)doInstallIntegrations {
    SentryOptions *options = [self getClient].options;
    for (NSString *integrationName in [self getClient].options.integrations) {
        Class integrationClass = NSClassFromString(integrationName);
        if (nil == integrationClass) {
            NSString *logMessage = [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] couldn't find \"%@\" -> skipping.", integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        } else if ([SentrySDK.currentHub isInstalledIntegration:integrationClass]) {
            NSString *logMessage = [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] already installed \"%@\" -> skipping.", integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        }
        id<SentryIntegrationProtocol> integrationInstance = [[integrationClass alloc] init];
        [integrationInstance installWithOptions:options];
        [SentrySDK.currentHub.installedIntegrations addObject:integrationInstance];
    }
    return [self getClient].options.integrations.count == SentrySDK.currentHub.installedIntegrations.count;
}

- (BOOL)isInstalledIntegration:(Class)integrationClass {
    for (id<SentryIntegrationProtocol> item in SentrySDK.currentHub.installedIntegrations) {
        if ([item isKindOfClass:integrationClass]) {
            return YES;
        }
    }
    return NO;
}

@end
