#import "SentryUIDeviceWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIDeviceWrapper ()
@property (nonatomic) BOOL cleanupDeviceOrientationNotifications;
@property (nonatomic) BOOL cleanupBatteryMonitoring;
@end

@implementation SentryUIDeviceWrapper

#if TARGET_OS_IOS

- (void)start
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchOnMainQueue:^{
        if (!UIDevice.currentDevice.isGeneratingDeviceOrientationNotifications) {
            self.cleanupDeviceOrientationNotifications = YES;
            [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
        }

        // Needed so we can read the battery level
        if (!UIDevice.currentDevice.isBatteryMonitoringEnabled) {
            self.cleanupBatteryMonitoring = YES;
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        }
    }];
}

- (void)stop
{
    BOOL needsCleanUp = self.cleanupDeviceOrientationNotifications;
    BOOL needsDisablingBattery = self.cleanupBatteryMonitoring;
    UIDevice *device = [SENTRY_UIDevice currentDevice];
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchOnMainQueue:^{
        if (needsCleanUp) {
            [device endGeneratingDeviceOrientationNotifications];
        }
        if (needsDisablingBattery) {
            device.batteryMonitoringEnabled = NO;
        }
    }];
}

- (void)dealloc
{
    [self stop];
}

- (UIDeviceOrientation)orientation
{
    return (UIDeviceOrientation)[SENTRY_UIDevice currentDevice].orientation;
}

- (BOOL)isBatteryMonitoringEnabled
{
    return [SENTRY_UIDevice currentDevice].isBatteryMonitoringEnabled;
}

- (UIDeviceBatteryState)batteryState
{
    return (UIDeviceBatteryState)[SENTRY_UIDevice currentDevice].batteryState;
}

- (float)batteryLevel
{
    return [SENTRY_UIDevice currentDevice].batteryLevel;
}

#endif

@end

NS_ASSUME_NONNULL_END
