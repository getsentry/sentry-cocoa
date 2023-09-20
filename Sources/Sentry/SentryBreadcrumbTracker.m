#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbDelegate.h"
#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryReachability.h"
#import "SentryScope.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentrySwizzleWrapper.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif // !TARGET_OS_WATCH

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryBreadcrumbTrackerSwizzleSendAction
    = @"SentryBreadcrumbTrackerSwizzleSendAction";

@interface
SentryBreadcrumbTracker () <SentryReachabilityObserver>

@property (nonatomic, weak) id<SentryBreadcrumbDelegate> delegate;

@end

@implementation SentryBreadcrumbTracker

#if !TARGET_OS_WATCH
- (void)dealloc
{
    [SentryDependencyContainer.sharedInstance.reachability removeObserver:self];
}
#endif // !TARGET_OS_WATCH

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
{
    _delegate = delegate;
    [self addEnabledCrumb];
    [self trackApplicationUIKitNotifications];
#if !TARGET_OS_WATCH
    [self trackNetworkConnectivityChanges];
#endif // !TARGET_OS_WATCH
}

- (void)startSwizzle
{
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
}

- (void)stop
{
    // All breadcrumbs are guarded by checking the client of the current hub, which we remove when
    // uninstalling the SDK. Therefore, we don't clean up everything.
#if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.swizzleWrapper
        removeSwizzleSendActionForKey:SentryBreadcrumbTrackerSwizzleSendAction];
#endif // SENTRY_HAS_UIKIT
    _delegate = nil;
}

- (void)trackApplicationUIKitNotifications
{
#if SENTRY_HAS_UIKIT
    NSNotificationName foregroundNotificationName = UIApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName = UIApplicationDidEnterBackgroundNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName foregroundNotificationName = NSApplicationDidBecomeActiveNotification;
    // Will resign Active notification is the nearest one to
    // UIApplicationDidEnterBackgroundNotification
    NSNotificationName backgroundNotificationName = NSApplicationWillResignActiveNotification;
#else // TARGET_OS_WATCH
    SENTRY_LOG_DEBUG(@"NO UIKit, OSX and Catalyst -> [SentryBreadcrumbTracker "
                     @"trackApplicationUIKitNotifications] does nothing.");
#endif // !TARGET_OS_WATCH

    // not available for macOS
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter
        addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    SentryBreadcrumb *crumb =
                        [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelWarning
                                                       category:@"device.event"];
                    crumb.type = @"system";
                    crumb.data = @ { @"action" : @"LOW_MEMORY" };
                    crumb.message = @"Low memory";
                    [self.delegate addBreadcrumb:crumb];
                }];
#endif // SENTRY_HAS_UIKIT

#if !TARGET_OS_WATCH
    [NSNotificationCenter.defaultCenter addObserverForName:backgroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType:@"navigation"
                                                                   withCategory:@"app.lifecycle"
                                                                      withLevel:kSentryLevelInfo
                                                                    withDataKey:@"state"
                                                                  withDataValue:@"background"];
                                                }];

    [NSNotificationCenter.defaultCenter addObserverForName:foregroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType:@"navigation"
                                                                   withCategory:@"app.lifecycle"
                                                                      withLevel:kSentryLevelInfo
                                                                    withDataKey:@"state"
                                                                  withDataValue:@"foreground"];
                                                }];
#endif // !TARGET_OS_WATCH
}

#if !TARGET_OS_WATCH
- (void)trackNetworkConnectivityChanges
{
    [SentryDependencyContainer.sharedInstance.reachability
         addObserver:self
        withCallback:^(BOOL connected, NSString *_Nonnull typeDescription) {
            SentryBreadcrumb *crumb =
                [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                               category:@"device.connectivity"];
            crumb.type = @"connectivity";
            crumb.data = [NSDictionary dictionaryWithObject:typeDescription forKey:@"connectivity"];
            [self.delegate addBreadcrumb:crumb];
        }];
}
#endif // !TARGET_OS_WATCH

- (void)addBreadcrumbWithType:(NSString *)type
                 withCategory:(NSString *)category
                    withLevel:(SentryLevel)level
                  withDataKey:(NSString *)key
                withDataValue:(NSString *)value
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:level category:category];
    crumb.type = type;
    crumb.data = @{ key : value };
    [self.delegate addBreadcrumb:crumb];
}

- (void)addEnabledCrumb
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"started"];
    crumb.type = @"debug";
    crumb.message = @"Breadcrumb Tracking";
    [self.delegate addBreadcrumb:crumb];
}

#if SENTRY_HAS_UIKIT
+ (BOOL)avoidSender:(id)sender forTarget:(id)target action:(NSString *)action
{
    if ([sender isKindOfClass:UITextField.self]) {
        // This is required to avoid creating breadcrumbs for every key pressed in a text field.
        // Textfield may invoke many types of event, in order to check if is a
        // `UIControlEventEditingChanged` we need to compare the current action to all events
        // attached to the control. This may cause a false negative if the developer is using the
        // same action for different events, but this trade off is acceptable because using the same
        // action for `.editingChanged` and another event is not supposed to happen.
        UITextField *textField = sender;
        NSArray<NSString *> *actions = [textField actionsForTarget:target
                                                   forControlEvent:UIControlEventEditingChanged];
        return [actions containsObject:action];
    }
    return NO;
}
#endif // SENTRY_HAS_UIKIT

- (void)swizzleSendAction
{
#if SENTRY_HAS_UIKIT
    SentryBreadcrumbTracker *__weak weakSelf = self;
    [SentryDependencyContainer.sharedInstance.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            if ([SentryBreadcrumbTracker avoidSender:sender forTarget:target action:action]) {
                return;
            }

            NSDictionary *data = nil;
            for (UITouch *touch in event.allTouches) {
                if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                    data = [SentryBreadcrumbTracker extractDataFromView:touch.view];
                }
            }

            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                                     category:@"touch"];
            crumb.type = @"user";
            crumb.message = action;
            crumb.data = data;
            [weakSelf.delegate addBreadcrumb:crumb];
        }
                   forKey:SentryBreadcrumbTrackerSwizzleSendAction];

#else // !SENTRY_HAS_UIKIT
    SENTRY_LOG_DEBUG(@"NO UIKit -> [SentryBreadcrumbTracker swizzleSendAction] does nothing.");
#endif // SENTRY_HAS_UIKIT
}

- (void)swizzleViewDidAppear
{
#if SENTRY_HAS_UIKIT

    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentryBreadcrumbTracker *__weak weakSelf = self;

    SentrySwizzleMode mode = SentrySwizzleModeOncePerClassAndSuperclasses;

#    if defined(TEST) || defined(TESTCI)
    // some tests need to swizzle multiple times, once for each test case. but since they're in the
    // same process, if they set something other than "always", subsequent swizzles fail. override
    // it here for tests
    mode = SentrySwizzleModeAlways;
#    endif // defined(TEST) || defined(TESTCI)

    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                                     category:@"ui.lifecycle"];
            crumb.type = @"navigation";
            crumb.data = [SentryBreadcrumbTracker fetchInfoAboutViewController:self];

            [weakSelf.delegate addBreadcrumb:crumb];

            SentrySWCallOriginal(animated);
        }),
        mode, swizzleViewDidAppearKey);
#    pragma clang diagnostic pop
#else // !SENTRY_HAS_UIKIT
    SENTRY_LOG_DEBUG(@"NO UIKit -> [SentryBreadcrumbTracker swizzleViewDidAppear] does nothing.");
#endif // SENTRY_HAS_UIKIT
}

#if SENTRY_HAS_UIKIT
+ (NSDictionary *)extractDataFromView:(UIView *)view
{
    NSMutableDictionary *result =
        @{ @"view" : [NSString stringWithFormat:@"%@", view] }.mutableCopy;

    if (view.tag > 0) {
        [result setValue:[NSNumber numberWithInteger:view.tag] forKey:@"tag"];
    }

    if (view.accessibilityIdentifier && ![view.accessibilityIdentifier isEqualToString:@""]) {
        [result setValue:view.accessibilityIdentifier forKey:@"accessibilityIdentifier"];
    }

    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        if (button.currentTitle && ![button.currentTitle isEqual:@""]) {
            [result setValue:[button currentTitle] forKey:@"title"];
        }
    }

    return result;
}

+ (NSDictionary *)fetchInfoAboutViewController:(UIViewController *)controller
{
    NSMutableDictionary *info = @{}.mutableCopy;

    info[@"screen"] = [SwiftDescriptor getObjectClassName:controller];

    if ([controller.navigationItem.title length] != 0) {
        info[@"title"] = controller.navigationItem.title;
    } else if ([controller.title length] != 0) {
        info[@"title"] = controller.title;
    }

    info[@"beingPresented"] = controller.beingPresented ? @"true" : @"false";

    if (controller.presentingViewController != nil) {
        info[@"presentingViewController"] =
            [SwiftDescriptor getObjectClassName:controller.presentingViewController];
    }

    if (controller.parentViewController != nil) {
        info[@"parentViewController"] =
            [SwiftDescriptor getObjectClassName:controller.parentViewController];
    }

    if (controller.view.window != nil) {
        info[@"window"] = controller.view.window.description;
        info[@"window_isKeyWindow"] = controller.view.window.isKeyWindow ? @"true" : @"false";
        info[@"window_windowLevel"] =
            [NSString stringWithFormat:@"%f", controller.view.window.windowLevel];
        info[@"is_window_rootViewController"]
            = controller.view.window.rootViewController == controller ? @"true" : @"false";
    }

    return info;
}
#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
