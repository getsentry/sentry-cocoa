//
//  SentryAutoBreadcrumbTrackingIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 05.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"

@interface SentryAutoBreadcrumbTrackingIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self enableAutomaticBreadcrumbTracking];
    return YES;
}

- (void)enableAutomaticBreadcrumbTracking {
    [[SentryBreadcrumbTracker alloc] start];
}

@end
