//
//  SentryBreadcrumbTracker.m
//  Sentry
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentrySwizzle.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryClient.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentryDefines.h"
#import "SentrySwizzle.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryLog.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif


@implementation SentryBreadcrumbTracker

- (void)start {
    [self addEnabledCrumb];
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
    [self trackApplicationUIKitNotifications];
}

- (void)trackApplicationUIKitNotifications {
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelWarning category:@"Device"];
                                                    crumb.type = @"system";
                                                    crumb.message = @"Memory Warning";
                                                    [SentrySDK addBreadcrumb:crumb];
                                                }];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker trackApplicationUIKitNotifications] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}
     
- (void)addEnabledCrumb {
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"started"];
    crumb.type = @"debug";
    crumb.message = @"Breadcrumb Tracking";
    [SentrySDK addBreadcrumb:crumb];
}

- (void)swizzleSendAction {
#if SENTRY_HAS_UIKIT
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    //    - (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication.class,
            selector,
            SentrySWReturnType(BOOL),
            SentrySWArguments(SEL action, id target, id sender, UIEvent * event),
            SentrySWReplacement({
                    if (nil != [SentrySDK.currentHub getClient]) {
                        NSDictionary *data = [NSDictionary new];
                        for (UITouch *touch in event.allTouches) {
                            if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                                data = @{@"view": [NSString stringWithFormat:@"%@", touch.view]};
                            }
                        }
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"touch"];
                        crumb.type = @"user";
                        crumb.message = [NSString stringWithFormat:@"%s", sel_getName(action)];
                        crumb.data = data;
                        [SentrySDK addBreadcrumb:crumb];
                    }
                    return SentrySWCallOriginal(action, target, sender, event);
            }), SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker swizzleSendAction] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

- (void)swizzleViewDidAppear {
#if SENTRY_HAS_UIKIT
    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(UIViewController.class,
            selector,
            SentrySWReturnType(void),
            SentrySWArguments(BOOL animated),
            SentrySWReplacement({
                    if (nil != [SentrySDK.currentHub getClient]) {
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"UIViewController"];
                        crumb.type = @"navigation";
                        crumb.message = @"viewDidAppear";
                        NSString *viewControllerName = [SentryBreadcrumbTracker sanitizeViewControllerName:[NSString stringWithFormat:@"%@", self]];
                        crumb.data = @{@"controller": viewControllerName};

                        [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull scope) {
                            [scope addBreadcrumb:crumb];
                            [scope setExtraValue:viewControllerName forKey:@"__sentry_transaction"];
                        }];
                    }
                    SentrySWCallOriginal(animated);
            }), SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker swizzleViewDidAppear] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

+ (NSRegularExpression *)viewControllerRegex {
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(NSString *)controller {
    NSRange searchedRange = NSMakeRange(0, [controller length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:controller options:0 range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[controller substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return controller;
}

@end
