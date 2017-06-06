//
//  SentryBreadcrumbTracker.m
//  Sentry
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/RSSwizzle.h>
#import <Sentry/SentryBreadcrumbStore.h>

#else
#import "SentryClient.h"
#import "SentryDefines.h"
#import "RSSwizzle.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbStore.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif


@implementation SentryBreadcrumbTracker

- (void)start {
    [self addEnabledCrumb];
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
}

- (void)addEnabledCrumb {
    if (nil != SentryClient.sharedClient) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"started"];
        crumb.type = @"debug";
        crumb.message = @"Breadcrumb Tracking";
        [SentryClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
    }
}

- (void)swizzleSendAction {
#if SENTRY_HAS_UIKIT
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    //    - (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    RSSwizzleInstanceMethod(UIApplication.class,
            selector,
            RSSWReturnType(BOOL),
            RSSWArguments(SEL action, id target, id sender, UIEvent * event),
            RSSWReplacement({
                    if (nil != SentryClient.sharedClient) {
                        NSDictionary *data = [NSDictionary new];
                        for (UITouch *touch in event.allTouches) {
                            if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                                data = @{@"view": [NSString stringWithFormat:@"%@", touch.view]};
                            }
                        }
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"touch"];
                        crumb.type = @"user";
                        crumb.message = [NSString stringWithFormat:@"%s", sel_getName(action)];
                        crumb.data = data;
                        [SentryClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
                    }
                    return RSSWCallOriginal(action, target, sender, event);
            }), RSSwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#endif
}

- (void)swizzleViewDidAppear {
#if SENTRY_HAS_UIKIT
    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    // -(void)viewDidAppear:(BOOL)animated
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    RSSwizzleInstanceMethod(UIViewController.class,
            selector,
            RSSWReturnType(void),
            RSSWArguments(BOOL animated),
            RSSWReplacement({
                    if (nil != SentryClient.sharedClient) {
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"UIViewController"];
                        crumb.type = @"navigation";
                        crumb.message = @"viewDidAppear";
                        crumb.data = @{@"controller": [NSString stringWithFormat:@"%@", self]};
                        [SentryClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
                    }
                    RSSWCallOriginal(animated);
            }), RSSwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#endif
}

@end
