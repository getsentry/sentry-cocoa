#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentrySystemEventBreadcrumbs.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *breadcrumbTracker;

#if TARGET_OS_IOS && UIKIT_LINKED
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;
#endif // TARGET_OS_IOS && UIKIT_LINKED

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [self installWithOptions:options
             breadcrumbTracker:[[SentryBreadcrumbTracker alloc] init]
#if TARGET_OS_IOS && UIKIT_LINKED
        systemEventBreadcrumbs:
            [[SentrySystemEventBreadcrumbs alloc]
                         initWithFileManager:[SentryDependencyContainer sharedInstance].fileManager
                andNotificationCenterWrapper:[SentryDependencyContainer sharedInstance]
                                                 .notificationCenterWrapper]
#endif // TARGET_OS_IOS && UIKIT_LINKED
    ];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoBreadcrumbTracking;
}

/**
 * For testing.
 */
- (void)installWithOptions:(nonnull SentryOptions *)options
         breadcrumbTracker:(SentryBreadcrumbTracker *)breadcrumbTracker
#if TARGET_OS_IOS && UIKIT_LINKED
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs
#endif // TARGET_OS_IOS && UIKIT_LINKED
{
    self.breadcrumbTracker = breadcrumbTracker;
    [self.breadcrumbTracker startWithDelegate:self];

    if (options.enableSwizzling) {
        [self.breadcrumbTracker startSwizzle];
    }

#if TARGET_OS_IOS && UIKIT_LINKED
    self.systemEventBreadcrumbs = systemEventBreadcrumbs;
    [self.systemEventBreadcrumbs startWithDelegate:self];
#endif // TARGET_OS_IOS && UIKIT_LINKED
}

- (void)uninstall
{
    if (nil != self.breadcrumbTracker) {
        [self.breadcrumbTracker stop];
    }
#if TARGET_OS_IOS && UIKIT_LINKED
    if (nil != self.systemEventBreadcrumbs) {
        [self.systemEventBreadcrumbs stop];
    }
#endif // TARGET_OS_IOS && UIKIT_LINKED
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK addBreadcrumb:crumb];
}

@end

NS_ASSUME_NONNULL_END
