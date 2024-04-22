#import "SentryAutoBreadcrumbTrackingIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentryBreadcrumbTracker, SentrySystemEventBreadcrumbs, SentryMemoryEventBreadcrumbs;

@interface
SentryAutoBreadcrumbTrackingIntegration (Test)

- (void)installWithOptions:(nonnull SentryOptions *)options
         breadcrumbTracker:(SentryBreadcrumbTracker *)breadcrumbTracker
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs
    memoryEventBreadcrumbs:(SentryMemoryEventBreadcrumbs *)memoryEventBreadcrumbs
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
    ;

@end

NS_ASSUME_NONNULL_END
