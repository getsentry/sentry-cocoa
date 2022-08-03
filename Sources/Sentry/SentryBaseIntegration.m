#import "SentryBaseIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryLog.h"
#import <Foundation/Foundation.h>
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryBaseIntegration

- (NSString *)integrationName
{
    return NSStringFromClass([self classForCoder]);
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![self shouldBeEnabledWithOptions:options]) {
        return NO;
    }

    return YES;
}

- (void)logWithOptionName:(NSString *)optionName
{
    [self logWithReason:[NSString stringWithFormat:@"because %@ is disabled", optionName]];
}

- (void)logWithReason:(NSString *)reason
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Not going to enable %@ %@.",
                                        self.integrationName, reason]
                     andLevel:kSentryLevelDebug];
}

- (BOOL)shouldBeEnabledWithOptions:(SentryOptions *)options
{
    SentryIntegrationOption integrationOptions = [self integrationOptions];

    if ((integrationOptions & kIntegrationOptionEnableAutoSessionTracking)
        && !options.enableAutoSessionTracking) {
        [self logWithOptionName:@"enableAutoSessionTracking"];
        return NO;
    }

    if (integrationOptions & kIntegrationOptionEnableOutOfMemoryTracking) {
        if (!options.enableOutOfMemoryTracking) {
            [self logWithOptionName:@"enableOutOfMemoryTracking"];
            return NO;
        }

        if (NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] != nil) {
            [self logWithReason:@"because unit tests are running"];
            return NO;
        }
    }

    if ((integrationOptions & kIntegrationOptionEnableAutoPerformanceTracking)
        && !options.enableAutoPerformanceTracking) {
        [self logWithOptionName:@"enableAutoPerformanceTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableUIViewControllerTracking)
        && !options.enableUIViewControllerTracking) {
        [self logWithOptionName:@"enableUIViewControllerTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionAttachScreenshot) && !options.attachScreenshot) {
        [self logWithOptionName:@"attachScreenshot"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableUserInteractionTracing)
        && !options.enableUserInteractionTracing) {
        [self logWithOptionName:@"enableUserInteractionTracing"];
        return NO;
    }

    if (integrationOptions & kIntegrationOptionEnableAppHangTracking) {
        if (!options.enableAppHangTracking) {
            [self logWithOptionName:@"enableAppHangTracking"];
            return NO;
        }

        if (options.appHangTimeoutInterval == 0) {
            [self logWithReason:@"because appHangTimeoutInterval is 0"];
            return NO;
        }

        if ([SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced]) {
            [self logWithReason:@"because the debugger is attached"];
            return NO;
        }
    }

    if ((integrationOptions & kIntegrationOptionEnableNetworkTracking)
        && !options.enableNetworkTracking) {
        [self logWithOptionName:@"enableNetworkTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableFileIOTracking)
        && !options.enableFileIOTracking) {
        [self logWithOptionName:@"enableFileIOTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableNetworkBreadcrumbs)
        && !options.enableNetworkBreadcrumbs) {
        [self logWithOptionName:@"enableNetworkBreadcrumbs"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableCoreDataTracking)
        && !options.enableCoreDataTracking) {
        [self logWithOptionName:@"enableCoreDataTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableSwizzling) && !options.enableSwizzling) {
        [self logWithOptionName:@"enableSwizzling"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableAutoBreadcrumbTracking)
        && !options.enableAutoBreadcrumbTracking) {
        [self logWithOptionName:@"enableAutoBreadcrumbTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionIsTracingEnabled) && !options.isTracingEnabled) {
        [self logWithOptionName:@"isTracingEnabled"];
        return NO;
    }

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionNone;
}

@end

NS_ASSUME_NONNULL_END
