#import "SentryAutoBreadcrumbTrackingIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentryBreadcrumbTracker, SentrySystemEventBreadcrumbs;

@interface
SentryAutoBreadcrumbTrackingIntegration (Test)

- (void)installWithOptions:(nonnull SentryOptions *)options
         breadcrumbTracker:(SentryBreadcrumbTracker *)breadcrumbTracker
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs;

@end

NS_ASSUME_NONNULL_END
