#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryDependencyContainer.h"
#import "SentrySystemEventBreadcrumbs.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoBreadcrumbTrackingIntegration ()

@property (nonatomic, strong) SentryBreadcrumbTracker *breadcrumbTracker;
@property (nonatomic, strong) SentrySystemEventBreadcrumbs *systemEventBreadcrumbs;

@end

@implementation SentryAutoBreadcrumbTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{

    [self installWithOptions:options
           breadcrumbTracker:[[SentryBreadcrumbTracker alloc]
                                   initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance]
                                                              .swizzleWrapper]
      systemEventBreadcrumbs:[[SentrySystemEventBreadcrumbs alloc]
                              initWithFileManager: [SentryDependencyContainer sharedInstance].fileManager andCurrentDateProvider: [SentryDefaultCurrentDateProvider sharedInstance]]
    ];
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
