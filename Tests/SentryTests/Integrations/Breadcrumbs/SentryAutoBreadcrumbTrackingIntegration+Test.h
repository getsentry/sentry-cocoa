#import "SentryAutoBreadcrumbTrackingIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentryBreadcrumbTracker, SentrySystemEventsBreadcrumbs;

@interface
SentryAutoBreadcrumbTrackingIntegration (Test)

- (void)installWithOptions:(nonnull SentryOptions *)options
                   tracker:(SentryBreadcrumbTracker *)tracker
              systemEvents:(SentrySystemEventsBreadcrumbs *)systemEvents;

@end

NS_ASSUME_NONNULL_END
