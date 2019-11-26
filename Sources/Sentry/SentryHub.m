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
#import <Sentry/SentryBreadcrumbs.h>
#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentrySentryStackLayer.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumbs.h"
#endif

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
/**
 */
- (void)setupWithClient:(SentryClient * _Nullable)client {
    SentryStackLayer *stackLayer = [SentryStackLayer new];
    stackLayer.scope = [SentryScope new];
    [self setStack:[@[stackLayer] mutableCopy]];
}

- (void)captureEvent:(SentryEvent *)event {
    [[self getClient] sendEvent:event scope:[self getScope] withCompletionHandler:nil];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [[self getScope].breadcrumbs addBreadcrumb:crumb];
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
    SentryStackLayer *newLayer = [SentryStackLayer new];
    newLayer.scope = scope;
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

@end
