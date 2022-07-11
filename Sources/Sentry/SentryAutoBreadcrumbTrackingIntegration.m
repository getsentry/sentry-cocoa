#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"
#import "SentrySystemEventBreadcrumbs.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *breadcrumbTracker;
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    if (!options.enableAutoBreadcrumbTracking) {
        [SentryLog logWithMessage:@"Not going to enable BreadcrumbTracking because "
                                  @"enableAutoBreadcrumbTracking is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    [self installWithOptions:options
             breadcrumbTracker:[[SentryBreadcrumbTracker alloc]
                                   initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance]
                                                              .swizzleWrapper]
        systemEventBreadcrumbs:[[SentrySystemEventBreadcrumbs alloc]
                                      initWithFileManager:[SentryDependencyContainer sharedInstance]
                                                              .fileManager
                                   andCurrentDateProvider:[SentryDefaultCurrentDateProvider
                                                              sharedInstance]]];
}

/**
 * For testing.
 */
- (void)installWithOptions:(nonnull SentryOptions *)options
         breadcrumbTracker:(SentryBreadcrumbTracker *)breadcrumbTracker
    systemEventBreadcrumbs:(SentrySystemEventBreadcrumbs *)systemEventBreadcrumbs
{
    self.breadcrumbTracker = breadcrumbTracker;
    [self.breadcrumbTracker start];

    if (options.enableSwizzling) {
        [self.breadcrumbTracker startSwizzle];
    }

    self.systemEventBreadcrumbs = systemEventBreadcrumbs;
    [self.systemEventBreadcrumbs start];
}

- (void)uninstall
{
    if (nil != self.breadcrumbTracker) {
        [self.breadcrumbTracker stop];
    }
    if (nil != self.systemEventBreadcrumbs) {
        [self.systemEventBreadcrumbs stop];
    }
}

@end

NS_ASSUME_NONNULL_END
