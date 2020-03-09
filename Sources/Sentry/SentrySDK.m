//
//  SentrySDK.m
//  Sentry
//
//  Created by Klemens Mantzos on 12.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryMeta.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryLog.h>
#else
#import "SentryMeta.h"
#import "SentrySDK.h"
#import "SentryClient.h"
#import "SentryScope.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryLog.h"
#endif

static SentryLogLevel logLevel = kSentryLogLevelError;

@interface SentrySDK ()

/**
 holds the current hub instance
 */
@property (class) SentryHub * currentHub;

@end

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK

static SentryHub *currentHub;

@dynamic logLevel;

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

+ (id)initWithOptions:(NSDictionary<NSString *,id> *)optionsDict {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:optionsDict didFailWithError:&error];
    if (nil != error) {
        [SentryLog logWithMessage:@"Error while initializing the SDK" andLevel:kSentryLogLevelError];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"%@", error] andLevel:kSentryLogLevelError];
    } else {
        [SentrySDK initWithOptionsObject:options];
    }
    return nil;
}

+ (id)initWithOptionsObject:(SentryOptions *)options {
    if ([SentrySDK.currentHub getClient] == nil) {
        SentryClient *newClient = [[SentryClient alloc] initWithOptions:options];
        [SentrySDK.currentHub bindClient:newClient];
    }
    [SentryLog logWithMessage:[NSString stringWithFormat:@"SDK initialized! Version: %@", SentryMeta.versionString] andLevel:kSentryLogLevelDebug];
    return nil;
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event {
    return [SentrySDK captureEvent:event withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureEvent:event withScope:scope];
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    return [SentrySDK.currentHub captureEvent:event withScope:scope];
}

+ (NSString *_Nullable)captureError:(NSError *)error {
    return [SentrySDK captureError:error withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureError:error withScope:scope];
}

+ (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    return [SentrySDK.currentHub captureError:error withScope:scope];
}

+ (NSString *_Nullable)captureException:(NSException *)exception {
    return [SentrySDK captureException:exception withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureException:(NSException *)exception withScopeBlock:(void (^)(SentryScope *_Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureException:exception withScope:scope];
}

+ (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    return [SentrySDK.currentHub captureException:exception withScope:scope];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message {
    return [SentrySDK captureMessage:message withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope * _Nonnull))block {
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureMessage:message withScope:scope];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    return [SentrySDK.currentHub captureMessage:message withScope:scope];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentrySDK.currentHub addBreadcrumb:crumb];
}

+ (void)configureScope:(void(^)(SentryScope *scope))callback {
    [SentrySDK.currentHub configureScope:callback];
}

+ (void)setLogLevel:(SentryLogLevel)level {
    NSParameterAssert(level);
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
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
