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
#import <Sentry/SentryBreadcrumbStore.h>
#import <Sentry/SentryStackLayer.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbStore.h"
#import "SentrySentryStackLayer.h"
#import "SentryBreadcrumbTracker.h"
#endif

@interface SentryHub()

@property (nonatomic, strong) NSMutableArray<SentryStackLayer *> *stackLayers;

@end

@implementation SentryHub

/**
 */
- (void)setupWithClient:(SentryClient * _Nullable)client {
    SentryScope *scope = [[SentryScope alloc] initWithOptions:client.options];
    SentryStackLayer *stackLayer = [[SentryStackLayer alloc] initWithClient:client scope:scope];
    [self setStackLayers:[@[stackLayer] mutableCopy]];
}

- (void)captureEvent:(SentryEvent *)event {
    [[self getClient] sendEvent:event scope:[self getStackTop].scope withCompletionHandler:nil];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [[self getStackTop].scope.breadcrumbs addBreadcrumb:crumb];
}

- (SentryClient * _Nullable)getClient {
    if (nil != [self getStackTop]) {
        return [[self getStackTop] client];
    }
    return nil;
}

- (void)bindClient:(SentryClient * _Nullable)newClient {
    return;
    //SentryClient *client = [self getClient];
    if (nil != [self getStackTop]) {
        [self getStackTop].client = newClient;
    }
}

- (SentryStackLayer *)getStackTop {
    //return [self.stackLayers lastObject];
    return self.stackLayers[self.stackLayers.count - 1];
}

- (SentryScope *)pushScope {
    SentryClient * client = [self getClient];
    SentryScope * scope = [[[self getStackTop] scope] copy];
    SentryStackLayer *newStackLayer = [[SentryStackLayer alloc] initWithClient:client scope:scope];
    [self.stackLayers addObject:newStackLayer];
    return scope;
}

- (void)popScope {
    [self.stackLayers removeLastObject];
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

@end
