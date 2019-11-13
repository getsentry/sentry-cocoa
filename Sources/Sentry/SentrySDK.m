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
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryHub.h>
#else
#import "SentrySDK.h"
#import "SentryClient.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#endif

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK

+ (void)startWithOptions:(NSDictionary<NSString *,id> *)options {
    [SentryHub.defaultHub initWithOptions:options];
}

+ (void)captureEvent:(SentryEvent *)event {
    [SentryHub.defaultHub captureEvent:event];
}

+ (void)captureError:(NSError *)error {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = error.localizedDescription;
    [SentrySDK captureEvent:event];
}

+ (void)captureException:(NSException *)exception {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = exception.reason;
    [SentrySDK captureEvent:event];
}

+ (void)captureMessage:(NSString *)message {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = message;
    [SentrySDK captureEvent:event];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryHub.defaultHub addBreadcrumb:crumb];
}

// TODO(fetzig): requires scope that is detached from SentryClient.finish this as soon as SentryScope has been implemented.
//+ (void)configureScope:(void(^)(int))callback;

@end

NS_ASSUME_NONNULL_END
