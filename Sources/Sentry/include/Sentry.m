//
//  Sentry.m
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/Sentry.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryHub.h>
#else
#import "Sentry.h"
#import "SentryClient.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation Sentry

+ (void)initWithDsn:(NSString *)dsn {
    [SentryHub.defaultHub initWithOptions:@{@"dsn": dsn}];
}

+ (void)initWithOptions:(NSDictionary<NSString *,id> *)options {
    [SentryHub.defaultHub initWithOptions:options];
}

+ (void)captureEvent:(SentryEvent *)event {
    [SentryHub.defaultHub captureEvent:event];
}

+ (void)captureError:(NSError *)error {
    [SentryHub.defaultHub captureError:error];
}

+ (void)captureException:(NSException *)exception {
    [SentryHub.defaultHub captureException:exception];
}

+ (void)captureMessage:(NSString *)message {
    [SentryHub.defaultHub captureMessage:message];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryHub.defaultHub addBreadcrumb:crumb];
}

// TODO(fetzig): requires scope that is detached from SentryClient.finish this as soon as SentryScope has been implemented.
//+ (void)configureScope:(void(^)(int))callback;

@end

NS_ASSUME_NONNULL_END
