//
//  SentryAutoBreadcrumbTrackingIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 05.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryAutoBreadcrumbTrackingIntegration.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryEvent.h>
#else
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#endif

@interface SentryAutoBreadcrumbTrackingIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self enableAutomaticBreadcrumbTracking];
}

- (void)enableAutomaticBreadcrumbTracking {
    [[SentryBreadcrumbTracker alloc] start];
}

@end
