//
//  SentryUIKitMemoryWarningIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 05.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "SentryUIKitMemoryWarningIntegration.h"
#import "SentryInstallation.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentrySDK.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

@interface SentryUIKitMemoryWarningIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryUIKitMemoryWarningIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self trackMemoryPressureAsEvent];
    return YES;
}

- (void)trackMemoryPressureAsEvent {
#if SENTRY_HAS_UIKIT
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"Memory Warning";
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [SentrySDK captureEvent:event];
                                                }];
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryUIKitMemoryWarningIntegration does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

@end
