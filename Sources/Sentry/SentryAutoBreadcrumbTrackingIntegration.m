#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySystemEventsBreadcrumbs.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *tracker;
@property (nonatomic, strong) SentrySystemEventsBreadcrumbs *system_events;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    [self installWithOptions:options
                     tracker:[[SentryBreadcrumbTracker alloc] init]
                systemEvents:[[SentrySystemEventsBreadcrumbs alloc] init]];
}

/**
 * For testing.
 */
- (void)installWithOptions:(nonnull SentryOptions *)options
                   tracker:(SentryBreadcrumbTracker *)tracker
              systemEvents:(SentrySystemEventsBreadcrumbs *)systemEvents
{
    self.tracker = tracker;
    [self.tracker start];

    if (options.enableSwizzling) {
        [self.tracker startSwizzle];
    }

    self.system_events = systemEvents;
    [self.system_events start];
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
    if (nil != self.system_events) {
        [self.system_events stop];
    }
}

@end

NS_ASSUME_NONNULL_END
