//
//  SentrySDK.m
//  Sentry
//
//  Created by Klemens Mantzos on 12.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryLog.h>
#else
#import "SentrySDK.h"
#import "SentryClient.h"
#import "SentryScope.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryLog.h"
#endif

@interface SentrySDK ()

/**
 holds the current hub instance
 */
@property (class) SentryHub * currentHub;

@end

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK

static SentryHub * currentHub;

+ (SentryHub *)currentHub {
    @synchronized(self) {
        if (nil == currentHub) {
            currentHub = [[SentryHub alloc] init];
        }
        return currentHub;
    }
}

+ (void)setCurrentHub:(SentryHub *)hub {
    @synchronized(self) {
        currentHub = hub;
    }
}

+ (void)startWithOptionsDict:(NSDictionary<NSString *,id> *)optionsDict {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:optionsDict didFailWithError:&error];
    if (nil != error) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"SentrySDK startWithOptionsDict: ERROR: %@", error] andLevel:kSentryLogLevelDebug];
    } else {
        [SentrySDK startWithOptions:options];
    }
}

+ (void)startWithOptions:(SentryOptions *)options {
    if ([SentrySDK.currentHub getClient] == nil) {
        SentryClient *newClient = [[SentryClient alloc] initWithOptions:options];
        [SentrySDK.currentHub bindClient:newClient];
    }
}

+ (void)captureEvent:(SentryEvent *)event {
    [SentrySDK captureEvent:event withScope:nil];
}

+ (void)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    [SentrySDK captureEvent:event withScope:scope];
}

+ (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    [SentrySDK.currentHub captureEvent:event withScope:scope];
}

+ (void)captureError:(NSError *)error {
    [SentrySDK captureError:error withScope:nil];
}

+ (void)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    [SentrySDK captureError:error withScope:scope];
}

+ (void)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    [SentrySDK.currentHub captureError:error withScope:scope];
}

+ (void)captureException:(NSException *)exception {
    [SentrySDK captureException:exception withScope:nil];
}

+ (void)captureException:(NSException *)exception withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    [SentrySDK captureException:exception withScope:scope];
}

+ (void)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    [SentrySDK.currentHub captureException:exception withScope:scope];
}

+ (void)captureMessage:(NSString *)message {
    [SentrySDK captureMessage:message withScope:nil];
}

+ (void)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope * _Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    [SentrySDK captureMessage:message withScope:scope];
}

+ (void)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    [SentrySDK.currentHub captureMessage:message withScope:scope];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentrySDK.currentHub addBreadcrumb:crumb];
}

+ (void)configureScope:(void(^)(SentryScope *scope))callback {
    [SentrySDK.currentHub configureScope:callback];
}

#ifndef __clang_analyzer__
// Code not to be analyzed
+ (void)crash {
    int* p = 0;
    *p = 0;
}
#endif

@end

NS_ASSUME_NONNULL_END
