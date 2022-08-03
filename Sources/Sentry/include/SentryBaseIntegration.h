#import "SentryOptions.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, SentryIntegrationOption) {
    kIntegrationOptionNone = 0,
    kIntegrationOptionEnableAutoSessionTracking = 1 << 0,
    kIntegrationOptionEnableOutOfMemoryTracking = 1 << 1,
    kIntegrationOptionEnableAutoPerformanceTracking = 1 << 2,
    kIntegrationOptionEnableUIViewControllerTracking = 1 << 3,
    kIntegrationOptionAttachScreenshot = 1 << 4,
    kIntegrationOptionEnableUserInteractionTracing = 1 << 5,
    kIntegrationOptionEnableAppHangTracking = 1 << 6,
    kIntegrationOptionEnableNetworkTracking = 1 << 7,
    kIntegrationOptionEnableFileIOTracking = 1 << 8,
    kIntegrationOptionEnableNetworkBreadcrumbs = 1 << 9,
    kIntegrationOptionEnableCoreDataTracking = 1 << 10,
    kIntegrationOptionEnableSwizzling = 1 << 11,
    kIntegrationOptionEnableAutoBreadcrumbTracking = 1 << 12,
    kIntegrationOptionIsTracingEnabled = 1 << 13,
};

@interface SentryBaseIntegration : NSObject

- (NSString *)integrationName;
- (BOOL)installWithOptions:(SentryOptions *)options;
- (BOOL)shouldBeEnabledWithOptions:(SentryOptions *)options;
- (SentryIntegrationOption)integrationOptions;

@end

NS_ASSUME_NONNULL_END
